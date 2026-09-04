# Account deletion: authoritative rollout guide

This guide supersedes the earlier Phase 8 foundation/worker slice notes for rollout decisions. All work in this completion pass is LOCAL. No deployment, real-project migration, Console change, commit or push is authorized or performed.

## Contract and state machine

The Flutter account header is above both email verification and profile completion. Delete Account explains permanent deletion, future organized match cancellation, departure from future joined matches, historical anonymization and rating removal. Password reauthentication, Auth reload and forced token refresh precede the App Check protected `requestAccountDeletion` callable. The callable accepts an empty payload only and derives UID from recent authenticated context (five minutes); verification/profile completion are not admission requirements.

A transaction creates `accountDeletionBarriers/{uid}`, `accountDeletionJobs/{uid}` and `accountDeletionOutbox/{uid}`, preserves the first `deletionRequestedAt`, and deletes private/public profiles. Replays preserve that cutoff. `{status: "accepted"}` means a durable request, **not completed cleanup**. No privileged client Firestore writes or client Auth deletion occur.

Phases: `disableAuth → accepted → matches → joinRequests → notifications → ratings → verify → deleteAuth → complete`. Auth is disabled and refresh tokens revoked before cleanup. Each cleanup handler uses the existing bounded pages, durable checkpoints and fenced ordered transition. Status is pending, retry_wait, blocked or completed. Verification rejects residual references or malformed state before advancing to deleteAuth. Worker exceptions do not imply completion.

The deletion screen replaces the authenticated screen tree, disposing its listeners. Acceptance signs out and displays a background-processing receipt. Password/network/recent-auth errors are explained; a timeout or lost response is explicitly uncertain and safe to retry. A disabled/missing account is described as unavailable and possibly already processing, never falsely confirmed completed. The screen offers sign-out; the backend barrier remains authoritative after restart. ProfileGate never automatically writes a profile, and rules prevent profile recreation by old sessions. Current UI supports the app's password accounts; adding another sign-in provider requires its reauthentication flow.

## Cleanup and privacy

The cutoff is immutable. Future organizer matches are cancelled; past organizer identity is replaced. Future participants leave with capacity adjusted; past participant entries are replaced. The exact anonymous map is `{deleted: true, displayName: "Deleted player"}`. It has no UID, email or level. It is server-written historical data, never a valid account. Flutter clears even stray legacy identity fields when reading a deleted marker, shows Deleted player, disables profile navigation and excludes it from rating candidates.

Join requests involving the account and descendants of cancelled matches are removed, followed by related notifications and ratings. Ratings use the single deterministic contribution reconciler, preserving exact aggregates for surviving players. Existing email-bearing join requests remain readable; new client serialization omits email and create rules reject it.

Finalization requires a live owner/token lease, verified deleteAuth phase, verification receipt/cutoff and consistent barrier/outbox. Admin `deleteUser` receives only the stored job UID. Success or `auth/user-not-found` permits progress; every other failure preserves the job. Replays are safe, including a crash after Auth deletion. Fencing is checked again before receipt writes. Manifest deletion is bounded to 100 documents per call; Auth deletion may be repeated while manifests drain.

Completion atomically replaces the job, barrier and outbox with minimal receipts: UID/path identity, schema version, original request timestamp, completed timestamp and lifecycle status (plus job phase/outbox job ID). Lease, retry, error details and cleanup checkpoints are discarded. The consumed outbox has no dispatch timestamp. Permanent barriers prevent same-UID profile recreation. No names/emails are retained in receipts. Treat receipt UIDs as restricted pseudonymous personal identifiers; server-only access and an approved retention policy remain operational requirements.

## Dispatch and recovery

`recoverAccountDeletionJobs` is a second-generation scheduled function, every minute, maxInstances 1, timeout 120 seconds. It selects at most 20 due outbox records, ordered by `nextAttemptAt`, using the configured single-field index. No Cloud Tasks queue or task IAM is required.

Selection first moves the outbox visibility deadline two minutes forward. This makes interrupted work discoverable and rotates selected items to avoid starvation. The worker retries Auth lockdown when needed, acquires a fresh 90-second fenced lease and performs at most ten existing phase/page handlers. Successful incomplete work releases its lease and makes the outbox due again. Expired leases are acquired by a new token; job nextAttemptAt prevents early retries. Duplicate schedulers/deliveries are harmless.

Caught failures use exponential delay (capped at an hour), retaining checkpoints. Eight consecutive dispatch failures block the job instead of reporting completion; successful batches reset the failure counter. Existing handlers can block immediately on malformed data. Blocked jobs require operator repair; they are not automatically reset. The scheduler returns individual outcomes without abandoning other jobs. Alert on blocked jobs, old pending jobs, scheduler failures and increasing backlog. A hard process crash is recovered by visibility/lease expiry and is not counted as a caught failure.

The isolated first-generation `cleanupDeletedAuthUser` Auth onDelete trigger creates/replays the same admission pipeline using the trusted event UID. The existing outbox creation trigger locks Auth; the scheduler performs cleanup. Direct deletion is eventually consistent: the barrier is installed only when the event runs. Admin bulk `deleteUsers` does not emit per-user deletion events; do not use it as an account-deletion mechanism. Existing UID-only jobs are the recovery path. Arbitrary Auth deletion predating rollout needs separate inventory/operator attention.

## Dry-run-first preparation and accounting transition

`tool/prepare_account_deletion.mjs` requires `--project=...`. Production and unknown/mixed targets are refused. Dry-run is the default. Apply requires both `--apply` and `--writers-paused`; the latter is an operator assertion, not a mechanism that pauses traffic. Never supply it until the following maintenance window is established.

The tool reads 200 documents per page and refuses inventories beyond 100,000 records before writing. It inventories matches, public profiles, barriers, join requests, rating parent documents, ratings, contribution records, notifications and legacy aggregation events. It validates supported creator/player identities using worker semantics, rebuilds participantUids, removes legacy request emails and fills deterministic request userId, blocks orphaned/conflicting requests and rating parents, validates rating paths/fields/eligibility, replaces the contribution baseline and exact public aggregates, and retires legacy event markers. Malformed/ambiguous records block the entire known plan. No writes occur while an inventory blocker remains.

All proposed writes are planned before apply. Match/profile updates use update-time preconditions. Batches contain at most 200 writes. Exact projections make a partial application restartable: keep writers stopped, rerun full inventory/apply, then rerun dry-run until zero writes/blockers. This is not a cross-database snapshot; concurrent writers invalidate the maintenance procedure. Memory contains the bounded inventory/plan, including sensitive source records; avoid capturing process dumps. Reports contain paths and categories, not raw records.

Accounting order is mandatory to prevent double-counting:

1. Disable admission and stop client rating/membership writes in staging maintenance mode.
2. Stop/delete the old increment/event-marker aggregator and drain its deliveries. Keep the new reconciler disabled with `PADELX_RATING_CONTRIBUTIONS_READY` unset. Stop deletion workers during preparation.
3. Review dry-run, repair blockers, rerun dry-run, then explicitly apply. Contributions and exact aggregates are established together within this paused interval; legacy markers are removed only after the old trigger cannot run.
4. Rerun dry-run; require zero blockers and zero planned writes. Never run the old scalability aggregate migration after enabling contribution accounting.
5. Deploy/enable the current reconciler with `PADELX_RATING_CONTRIBUTIONS_READY=true`. It reads current sources and deterministic contributions, so delayed events converge without increments being applied twice.
6. Resume ordinary writes, validate reconciliation, and only then enable deletion admission and recovery.

The tool inventories known application descendant schemas. Unknown subcollections/export artifacts and backups require separate retention review. Existing ratingRaters parent documents should not contain personal fields; unexpected descendant schemas must be investigated before rollout.

## Rules and indexes

Existing verified-email and deletion-barrier protections remain in place. Deletion infrastructure, nested manifests, contributions and old aggregation events are server-only. Rules prohibit new references to deleting accounts where supported and prohibit old sessions recreating profiles. The existing anonymous schema has no identity keys, so rules do not need to accept it as a valid player on client creation. Historical reads remain supported. No authorization was weakened. Cleanup group indexes remain; an explicit ascending COLLECTION index for outbox nextAttemptAt documents the recovery query requirement.

## Staging setup and deployment order

Only allowlisted `padelx-staging` is eligible; production `padelx-f168f` remains refused by backend/tool guards. Explicit Firebase project configuration must agree across environment variables and Admin app.

1. Review local diff/tests and backups/retention policy. Configure staging App Check and client Firebase options.
2. Establish maintenance/accounting transition above. Deploy indexes and preserved rules, wait until indexes are ready, and validate them with staging queries.
3. Enable Cloud Functions, Cloud Run, Eventarc, Pub/Sub, Cloud Scheduler, Firestore and Identity Toolkit APIs as required by Firebase deployment. Billing must support scheduled functions. Deploying the schedule creates its Scheduler job; no Cloud Tasks resources are needed.
4. Use a dedicated runtime service account with Firestore data read/write (`roles/datastore.user`) and Auth user update/revoke/delete access (`roles/firebaseauth.admin`, or a reviewed narrower custom role). Restrict deployment permissions to the deployment operator. The Scheduler service identity needs invocation permission on the scheduled function's Cloud Run service; Firebase normally configures this binding during deployment. Verify the binding rather than exposing an HTTP endpoint publicly. First-generation Auth fallback and second-generation worker must share the trusted project/environment configuration.
5. Deploy disabled admission/recovery plus isolated Auth fallback; establish contribution baseline and enable the reconciler in the order above. Set `PADELX_ACCOUNT_DELETION_ENABLED=true` only after backend recovery and accounting are ready.
6. Deploy the client; exercise a disposable staging password account, including unverified/incomplete profile, lost response, history, aggregates and final Auth absence. Confirm Scheduler delivery, expired-lease recovery and blocked-job alerts. Do not treat local emulator scheduling as evidence of deployed Scheduler/IAM behavior.

## Recovery, rollback and production prerequisites

Turning admission off is not an undo. Existing requests must still be completed or supervised; this local recovery implementation shares the enable flag, so leave it enabled while draining existing jobs or run supervised recovery with the reviewed flag configuration. Never roll back to the old increment aggregator after establishing contributions. Never remove barriers to unblock users, recreate profiles, alter the original cutoff, or force complete status. Repair the actual malformed source, then reset a blocked job to pending and make its outbox nextAttemptAt due using a reviewed server-only procedure. Preserve checkpoint semantics; if verification found a newly discovered reference, route back through appropriate cleanup under operator review rather than bypass verification. Auth deletion cannot be undone.

Before production: explicitly revise and review production guards, finish staging acceptance/IAM/scheduler/App Check checks, establish operator alerts and runbooks, approve minimal-receipt/backups retention, review export/unknown-descendant coverage, and verify all supported sign-in providers. No production enablement is included here.

## Retained staging validation evidence (2026-09-04)

The `padelx-staging` exercise completed account deletion end to end with a disposable account. The first cleanup attempt reached the ratings phase and then failed because the `ratings.raterUid` collection-group index was missing. Repeated scheduled attempts exhausted the retry budget and correctly left the job blocked; no later phase was bypassed and no completion was reported. After the `ratings.raterUid`, `ratings.ratedUid`, and `ratings.matchId` collection-group indexes were deployed and reached READY, the UID-scoped recovery tool found the exact eligible blocked state and safely resumed it. The scheduler then progressed through `ratings → verify → deleteAuth → complete`.

The retained final state was `barrier.status=deleted`, `job.status=completed`, `job.phase=complete`, and `outbox.status=consumed`, with no active lease and an empty cleanup manifest. A subsequent login no longer returned `USER_DISABLED` and instead returned invalid credentials, confirming permanent Firebase Auth deletion. This deliberate missing-index/fail-closed/recovery sequence is staging evidence only; it is not production validation.

## Files changed in this completion pass

Existing user work, including unrelated tracked/untracked dependency files, was preserved. This pass changed or added:

- `functions/account_deletion.js`
- `functions/account_deletion_worker.js`
- `functions/account_deletion_dispatch.js`
- `functions/account_deletion_auth_trigger.js`
- `functions/index.js`
- `lib/account_deletion.dart`
- `lib/main.dart`
- `pubspec.yaml`
- `pubspec.lock`
- `macos/Flutter/GeneratedPluginRegistrant.swift`
- `firestore.indexes.json`
- `package.json`
- `tool/prepare_account_deletion.mjs`
- `test/account_deletion_completion.test.mjs`
- `test/account_deletion_test.dart`
- `docs/account-deletion-rollout.md`
- `docs/phase8-account-deletion-foundation.md`
- `docs/phase8-account-deletion-worker.md`

The pre-existing Phase 8 rules changes remain intact; additional redundant rule guards attempted during this pass were removed after the expression-budget regression was caught. Existing rules tests cover infrastructure denial, profile recreation denial and reference barriers.

## Local validation commands

Use Node **22.23.2** (or supported Node 22) for backend validation:

```
flutter analyze
flutter test
npm run test:deletion
node --test test/*safety.test.mjs
git diff --check
```

`test:deletion` starts Functions/Auth/Firestore emulators for `demo-padelx-phase8` only and runs backend, phase, completion and rules suites sequentially to avoid shared emulator fixture interference. Some test modules use other explicit `demo-*` namespaces on the same local emulators. The scheduled trigger is loaded but delivery by deployed Cloud Scheduler must be validated in staging. The actual first-generation Auth deletion trigger is exercised locally.

Final local results (2026-09-04): Flutter analysis clean; **178 Flutter tests passed**; **163 Node 22 backend/Functions/Auth/Firestore/rules tests passed**; **11 migration/enrollment safety tests passed**; `git diff --check` passed. Combined end-to-end cleanup checks all four match outcomes, request/notification/rating removal, exact surviving aggregates, empty manifests and final Auth absence. Additional tests cover missing Auth, actual Auth onDelete delivery, duplicate/lost-response replay, stale fencing, future retry eligibility, exhausted retries, blocked admission preservation, dry-run/apply restartability and production refusal. Existing phase tests cover residual-reference verification and malformed-data blocking.

Git remains on `main`, uncommitted and unpushed, with 104 status entries including 62 pre-existing `functions/node_modules` entries. No pre-existing work was discarded. No staging or production migration/deployment was run. Remaining staging gates are actual-data dry-run review, maintenance preparation, deployed Scheduler/IAM/App Check checks, native/web client smoke tests and operational alerts/retention approval. Local emulator success does not certify these external gates.
