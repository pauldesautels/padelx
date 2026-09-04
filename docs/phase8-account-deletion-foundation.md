> Historical implementation notes. For the completed feature and rollout decisions, use [account-deletion-rollout.md](account-deletion-rollout.md).

# Phase 8 account deletion foundation — slice 1

The foundation section below records slice 1. The admission-only extension at
the end records the next local slice. No cleanup worker, Flutter deletion UI,
backfill, migration, or deployment is included.

## Environment boundary

`functions/backend_environment.js` is the shared project gate. Demo projects
require both Auth and Firestore on loopback emulator endpoints. Only the literal
`padelx-staging` project is accepted outside emulators. `padelx-f168f` is recognized
as production and rejected; unknown projects and mixed configurations fail closed.
Runtime project identity comes from server environment, never request data.
Existing Admin migration/enrollment entry points also validate before creating an
Admin app. Production enablement requires a separate reviewed change.

Functions initialize a project-bound named Admin app lazily, after validation.
SDK credentials must still be limited to staging by IAM. No service-account keys
belong in the client. Current helpers do not expose an HTTP endpoint.

## Server-owned state, schema version 1

- `accountDeletionBarriers/{uid}`: `uid`, `schemaVersion`, `status: deleting`,
  `deletionRequestedAt`.
- `accountDeletionJobs/{uid}`: the same UID/version/cutoff, `status`, `phase`,
  `checkpoint`, `attemptCount`, `nextAttemptAt`, `leaseExpiresAt`, `lastErrorCode`,
  `completedAt`.

`deletionStateFor` builds these initial values without writing anything. The
future admission transaction must persist both documents atomically, choose the
cutoff on the server, and preserve it on every retry. The UID is the deterministic
job key. Dates serialize as Firestore timestamps when written by Admin SDK.

Planned job states: pending -> running -> complete; transient failures enter
retry_wait then running; exhausted retries or invalid data enter blocked and
require operator recovery. Phases: accepted, disableAuth, matches, joinRequests,
notifications, ratings, verify, deleteAuth, complete. Workers must use leases and
transactional checkpoints; this slice defines the model, not transition workers.

Any barrier document blocks normal authenticated application access regardless
of its status. A completed barrier is not automatically cleared. Client reads and
writes to barriers/jobs/contributions are denied; rules can inspect barriers.
Other users' existing bounded queries retain their existing authorization shape.
New requests cannot target a deleting organizer, approvals cannot add a deleting
player, notifications cannot target a deleting recipient, and new ratings require
an existing active recipient public profile. Client profile creation cannot seed aggregate fields; only trusted accounting can
initialize them. Existing references are not removed
by this slice. “Active” currently means no deletion barrier, not an Admin Auth
lookup or moderation verdict.

`requireRecentAuthentication` assumes callable-verified `request.auth`; it uses
only `auth_time`, defaults to five minutes, rejects malformed/future/stale values,
and returns `request.auth.uid` regardless of payload UID. Future admission must
also verify revocation/disabled Auth state, App Check, and durable idempotency.
Unverified accounts must be able to request deletion without application access.

## Deterministic rating accounting

`ratingContributions/{sha256(fullRatingPath)}` stores schemaVersion, ratingPath,
matchId, raterUid, ratedUid, score. Direct document lookups need no new indexes.
No full cleanup-query index set is introduced here.

The on-write handler ignores event snapshots. One transaction reads the live
rating, contribution, target profile, match, and both deletion barriers. Eligible
ratings must have matching path/fields, a score 1..5, distinct participating UIDs,
a completed non-cancelled match, an existing target profile, and no barriers.
The aggregate changes by desired contribution minus recorded contribution.
Deletion/ineligibility removes the contribution. Missing profiles are never
recreated. Duplicate, delayed, and concurrently retried events converge on live
state. Score changes update the sum without adding another count. Zero counts
produce sum/average zero. Inconsistent baselines fail rather than clamp totals and
silently damage other users' ratings.

Barrier creation and match changes do not themselves fan out rating work. Future
workers must explicitly reconcile all affected rating paths. This is intentional:
this slice installs the safe primitive, not unbounded trigger-driven cleanup.

### Mandatory accounting transition before staging use

Staging reconciliation remains disabled unless
`PADELX_RATING_CONTRIBUTIONS_READY=true` is explicitly configured. Do not set that
flag merely to clear an error. Pause rating writes; retire/drain the old create
trigger; inventory valid ratings; establish one contribution per included rating;
reconcile exact profile totals; then enable the new on-write trigger and resume
writes. Trigger event-type replacement may require retiring the existing deployed
function before recreation; review deployment behavior during the staging plan.

The old event markers remain client-denied but are no longer read/written by the
new trigger. Backfill and marker retirement are future work. Do not rerun the old
scalability aggregate migration after starting contribution accounting without a
coordinated baseline repair. No transition is executed by repository tests.

## Local verification

- `npm run test:backend`
- `npm run test:functions` (demo project; Auth/Firestore/Functions emulators)
- `npm run test:rules` (explicit demo project)
- `flutter analyze`, `flutter test`, `git diff --check`

Tests must never select a real Firebase project. Emulator tests do not validate
staging IAM, App Check attestation, deployment transitions, or real task queues.

## Next slice

Implement admission callable with atomic barrier/job/profile handling, durable
outbox/dispatch, bounded workers and retry recovery, future-match cancellation,
past-match anonymous identities, request/notification cleanup, rating cleanup,
verification and final Auth deletion. Remove duplicated request emails through a
separately reviewed schema transition/backfill before enabling real deletion.
Add Auth disable/revoke/delete and external Auth-deletion recovery, then Flutter
reauthentication/deletion status UI and deleted-player rendering. Auth deletion
must be last; no client receives Admin privileges. Decide operational record
retention and add exact required worker query indexes in that slice.


## Admission-only extension (local, not deployed)

`requestAccountDeletion` is a second-generation callable. It accepts an empty
payload (or null), takes identity exclusively from `request.auth.uid`, and calls
the existing five-minute recent-auth helper. Unverified users are permitted.
Unknown fields, including UID/project overrides, are rejected. App Check is
required outside the Functions emulator. The existing backend environment gate
is unchanged; additionally, non-emulator admission requires the explicit server
flag `PADELX_ACCOUNT_DELETION_ENABLED=true`. Leave it unset until the cleanup
implementation and staging preparation have been validated.

The public response is exactly `{status: "accepted"}`. This confirms durable
acceptance, not cleanup completion or permanent Auth deletion. The transaction
creates one barrier, job, and `accountDeletionOutbox/{uid}`, and deletes both
`users/{uid}` and `publicProfiles/{uid}`. All three lifecycle records share one
server-chosen `deletionRequestedAt`. Concurrent/repeated requests reuse these
records and cutoff; inconsistent partial state fails closed for server repair.
Retrying also reasserts profile absence. No client can read or mutate these
records, and an old session cannot recreate either profile across the barrier.

Initial job additions are `phase: disableAuth`, `authDisabledAt: null`,
`authRevokedAt: null`, and `authMissing: false`, alongside the foundation fields.
The outbox contains `uid`, `jobId` (the same UID), `schemaVersion: 1`, fixed
`deletionRequestedAt`, `status: auth_pending`, `attemptCount: 0`,
`nextAttemptAt`, `leaseExpiresAt: null`, and `lastErrorCode: null`. Lease storage
is groundwork only; no cleanup lease consumer runs in this slice.

Only after the acceptance transaction commits does the callable attempt Auth
lockdown. It disables the Auth user, records successful disable progress, revokes
refresh tokens, and records successful revoke progress. Already-disabled users
are safe; `auth/user-not-found` is recorded as safe progress. No code in this
extension calls Auth delete. Successful checkpoints skip completed Auth calls on
retry, while a crash between Auth and a checkpoint can safely repeat that call.
Concurrent invocations may repeat disable/revoke; they do not create another job.

After both checkpoints, a transaction marks the job `pending / accepted` and
outbox `ready_for_cleanup`. This is the stopping point for this pass. Failures
leave the acceptance intact, record `retry_wait / disableAuth`, and retain an
`auth_pending` outbox with a sanitized error code, capped attempt counter (8),
and exponential next-attempt metadata. A concurrent failure cannot regress an
already finalized lockdown. The callable still returns the durable receipt.

The retry-enabled `lockAccountDeletionAuth` outbox-create trigger independently
finishes Auth lockdown after callable crashes or response loss. It rereads the
current job rather than trusting stale event snapshots. Platform retries govern
trigger delivery; `nextAttemptAt` is recovery/dispatcher groundwork, not a promise
that Eventarc follows that timestamp. Delivery retry exhaustion requires later
operator recovery from the retained outbox. The replaceable
`dispatchDeletionOutbox(db, adapter)` reads at most 20 due records and passes
`{jobId, status}` to an adapter. It never consumes outbox records on enqueue and
is not automatically invoked. Future adapters must deduplicate by job ID, route
`auth_pending` to lockdown recovery, and admit cleanup only after lockdown.
No Cloud Tasks queue, scheduler, IAM, or cleanup dispatch is provisioned here.

Local validation commands: `npm run test:backend`, `npm run test:admission`,
`npm run test:rules`, and `git diff --check`. The admission suite covers real callable transport, emulator
Auth disable/revoke, concurrent admission, transaction rollback, fixed cutoff,
partial failures, missing users, recovery after progress checkpoints, failed
queue adapters, and lifecycle/profile rules. App Check attestation and platform
retry delivery timing require later staging validation.

### Exact next small slice

Implement the durable cleanup dispatcher/lease skeleton only: bounded due-job
selection, lease contention and expiry, capped retry scheduling, checkpoint
acknowledgement, stale-job recovery, and a replaceable local queue adapter. Gate
entry on completed Auth lockdown. Exercise it against a no-op test phase; do
not add match/request/notification/rating cleanup or permanent Auth deletion in
that slice. Those semantics, preparation/backfill tooling, Flutter UI, and an
explicitly authorized staging rollout remain subsequent work.

Admission validation result (2026-09-04): 6 backend/unit tests, 9 focused
Functions/Auth/Firestore emulator tests, and 28 Firestore rules tests passed.
`git diff --check` passed. Flutter code is unchanged by this admission slice.
The Functions emulator used host Node 26 while the configured deployment runtime
is Node 22; validate that runtime before any staging rollout.
