> Historical implementation notes. For the completed feature and rollout decisions, use [account-deletion-rollout.md](account-deletion-rollout.md).

# Phase 8 worker lease and checkpoint primitive

Backend-only exports live in `functions/account_deletion_worker.js`. Nothing
invokes them automatically; there is no dispatcher or scheduler. Accepted and
bounded matches handlers are available for trusted invocation.
All entry points reuse `assertSafeFirestore`; no client project selection exists.

## Job fields

- `leaseOwner`: worker invocation identifier, string; null after failure release.
- `leaseToken`: fresh random token for each attempt, supplied by trusted worker.
  Retry an uncertain acquisition with the same owner/token. Never reuse a token
  for a later attempt. Retained after release to reject immediate resurrection.
- `leaseExpiresAt`: Firestore timestamp, null after failure release. Default lease
  duration is 60 seconds, capped at one hour. There is no heartbeat/renewal.
- Existing `attemptCount` increments exactly once per new acquisition, including
  reclaim after expiry; neither checkpoints nor failure acknowledgements increment it.
- Existing `nextAttemptAt` gates acquisition; failure sets a delay (default one
  second, maximum one hour), acquisition clears it.
- Existing `lastErrorCode` stores only `worker-work-failed`; a successful
  checkpoint clears it. Raw errors are never persisted by this primitive.

Acquisition transaction reads the job and outbox. Only pending/retry-wait,
nonterminal jobs with `ready_for_cleanup` outbox qualify. An active lease excludes
competitors; replay by its owner/token succeeds without extending expiry. An
expired lease requires a fresh token. No admission or outbox state is modified.

`runDeletionStep` checks ownership, awaits caller work, then checkpoints. Work
must be idempotent because a crash or lease loss after effects may replay it.
`checkpointDeletion` is also reusable directly, but callers must invoke it only
after successful work. It transactionally verifies unexpired owner/token and
current phase, then compares `expectedCheckpoint` before writing a larger integer
checkpoint. An exact replay is a no-op; older progress cannot overwrite newer
progress. Checkpoints are batch sequence numbers within the existing phase.
Checkpointing never changes phase, cutoff, or completion fields.

Failure releases the lease and records retry state without advancing checkpoint.
A stale worker cannot checkpoint or release a replacement lease. Successful
steps retain their lease until expiry. Optional injected times are for trusted
tests only; normal calls sample current time inside each transaction attempt.

Validation: Node 22 `npm run test:deletion-worker`, backend environment/admission
unit tests, and existing Firestore rules tests. Rules remain unchanged and deny
client reads/writes of jobs, barriers, and outbox.

## Fenced phase transitions

`DELETION_WORKER_PHASES` is the explicit cleanup order:
`accepted -> matches -> joinRequests -> notifications -> ratings -> verify -> deleteAuth`.
Existing names are retained. `accepted` is the preparation phase after admission
finishes `disableAuth`; admission remains unchanged. `deleteAuth` is only a
reserved stopping point: existing lease acquisition/checkpoint helpers exclude
it, this transition helper has no outgoing edge from it, and no Auth deletion
or completed-state transition is implemented.

`transitionDeletionPhase(db, uid, lease, { expectedPhase, nextPhase })` validates
that both phases are allowlisted and adjacent, then transactionally checks the
current unexpired owner/token, pending status, absent completion timestamp, and
expected phase. Blocked, terminal, and retry-wait jobs cannot transition.
The API is backend-only and has no callable/HTTP export; nextPhase is a trusted
worker assertion and cannot select an arbitrary phase or skip an edge.

Every phase uses `null` as its initial checkpoint and reserves
`DELETION_PHASE_COMPLETE_CHECKPOINT` (`Number.MAX_SAFE_INTEGER`) as its completion
marker. Ordinary numeric batch checkpoints do not permit transitions. The worker
must write the marker through the existing checkpoint helper only after all
phase work succeeds (or use `runDeletionStep` for the final successful work).
This marker is an explicit trusted-worker assertion, not proof of cleanup queries;
real phase-specific completion checks remain part of upcoming cleanup handlers.

A transition resets checkpoint to `null` and records `lastPhaseTransition` with
`from`, `to`, `leaseOwner`, and `leaseToken`. Owner, token, expiry, retry state,
cutoff, and completion fields are preserved. The lease is neither released nor
extended. A duplicate with the same live lease and matching receipt is a no-op,
even after next-phase checkpoint progress. Replay cannot reset that progress.
A replay after further phase transitions, expiry, or reclamation is rejected
without writes. One receipt suffices because backward transitions are prohibited.

## Accepted preparation

`runAcceptedDeletionPhase(db, auth, uid, lease)` validates all three lifecycle
records, schema/UID/job ID agreement, exact timestamp equality (including
nanoseconds), deleting barrier, ready outbox, pending job, absent completion,
and absence of both profiles. It pins the existing cutoff for the invocation
and rechecks it in transactions before progress writes and the final transition.
It never writes a cutoff. Malformed state fails closed without writes or an
automatic retry; a trusted repair is required before another attempt can succeed.

Auth progress must contain valid timestamps or explicit nulls and a boolean
`authMissing`. Revocation without disable progress is inconsistent. Missing
progress is resumed using the same idempotent Auth operation helper as admission;
each worker progress write is lease-fenced. User-not-found is recorded as safe
success, and revoke is still attempted after a missing disable. Completed
operations are skipped; an effect whose progress write was lost can be repeated.
The admission finalizer is not called, preserving phase and attempt metadata.

Auth failures use the existing sanitized worker retry state. Transient database
errors also request a retry; if the database remains unavailable or the lease
is lost, the lease can expire naturally. Completed progress is retained.
After validation and lockdown, the reserved checkpoint is recorded and the
existing transition helper advances only accepted to matches, resetting the
checkpoint. Both helpers accept a transaction validation callback so lifecycle
checks participate in their commit. Duplicate execution with the same live lease
preserves matches progress. No automatic invocation is added.

The matches handler below builds on this preparation and the existing primitives.

## Matches cleanup (bounded backend-only handler)

`runMatchesDeletionPhase(db, uid, lease, { pageSize = 100 })` processes at most
one page per call. Call again until `complete` is true; no dispatcher is added.
Three deterministic streams query `creatorUid == uid`, `createdBy == uid`, and
`participantUids array-contains uid`, each ordered by document ID. These use
Firestore's automatic single-field indexes (including their document-name
ordering); no new composite indexes are needed. Dates are validated and compared
inside the transaction, including nanoseconds, so missing dates cannot evade a
scheduledAt query filter. Identity is never inferred from email.

Each stream stores `{ after, done }` in `matchesCheckpoint`. Effects, per-match
`accountDeletionJobs/{uid}/matchCleanup/{matchId}` manifest entries, the stream
cursor and numeric page checkpoint commit atomically. Full pages require another
query to establish exhaustion. `matchesCutoff` pins the original cutoff across
invocations, compared with the job/barrier/outbox on every write. A transaction
reads and fences the lease and validates it again immediately before page writes.
Stale workers cannot write effects or progress. Match references are removed by
successful cleanup, so subsequent streams/retries cannot repeat spot restoration.
The manifest retains match IDs for later descendant work without an unbounded
array on the job. It contains no descendant cleanup implementation.

Future organized matches retain their document, venue and other participants,
with `status: cancelled`, `cancellationReason: organizer_deleted`. Both supported
owner UID fields and known creator/createdBy display-name, name, email and level
fields are removed. `organizer: { deleted: true, displayName: 'Deleted player' }`
is the explicit historical identity; the same organizer representation is used
for past matches without cancelling them. Organizer responsibility is never
transferred. Match-level `level` remains the match's requested skill level.

Future participants are removed from `players` and `participantUids`, restoring
one spot. Existing schema capacity is one organizer plus at most three players;
restored spots cannot exceed `3 - remainingPlayers.length`. Past player entries
are replaced in place with `{ deleted: true, displayName: 'Deleted player' }`,
containing no UID/userId/email/level or profile/rating target. Other players and
rating/history fields remain unchanged. UID and legacy userId player identities
are supported. Missing legacy organizer projections can be rebuilt; inconsistent
existing projections, conflicting IDs, duplicate membership, invalid dates,
unknown capacity fields, invalid spot counts, and email-only player identities
within a targeted record block instead of guessing.

Malformed matches atomically mark the job `blocked` with sanitized
`matches-ambiguous-state` and `matchesBlockedRecord`; the entire page remains
unchanged and its cursor does not advance. Trusted repair is required. Malformed
lifecycle/checkpoint state fails closed. Transient database failures retain
progress and use the existing retry helper. Once all three streams are exhausted,
the existing completion checkpoint and transition helper advance exactly
`matches -> joinRequests`, resetting the numeric checkpoint. Completion-marker
recovery and completed-phase replay are supported.

Next small slice: bounded join-request cleanup, using targeted user identity
queries and the match manifest for organized-match descendants. Notifications,
ratings, permanent Auth deletion, scheduling, deployment and migration remain
outside this slice.

### Bounded join-request phase

`runJoinRequestsDeletionPhase` performs one transactional page per invocation,
then records the phase-completion marker and fences `joinRequests → notifications`
when both streams are exhausted. It does not dispatch notification cleanup.

* User discovery uses the existing collection-group `userId == uid` index,
  ordered by full document path, without status or email filters. The supported
  global schema requires `userId`; Firestore cannot query a bare document ID
  across unknown parents. No migration or global scan is performed. Path-only
  legacy requests outside known manifest parents are not globally discoverable.
* The existing `matchCleanup` manifest is read one entry at a time, ordered by
  document ID. Future organized entries drain all `joinRequests` descendants;
  other entries probe the deleting UID's document for legacy path-only records.
  Parent match documents are not read. Manifest entries are retained for later
  phases; the job stores separate manifest and descendant cursors.
* Each page contains at most 100 requests. Deletes and cursor advancement commit
  atomically after whole-page validation and lease checks. An exact-size page
  requires another read to establish exhaustion. A fresh lease resumes persisted
  progress; lost acknowledgements and repeated cleanup are idempotent.
* The supported path is `matches/{matchId}/joinRequests/{uid}`. Any present `uid`
  or `userId` must be a valid UID equal to the path UID. Conflicts, unsupported
  paths, and malformed manifests preserve the entire page and block the job with
  `joinRequests-ambiguous-state` and `joinRequestsBlockedRecord`. Email is never
  an identity source. The original cutoff is checked, never rewritten.
* New client serialization omits email, and create/retry rule allowlists reject
  it. Legacy reads and status-only updates remain compatible with stored email;
  deleting the request removes every field. Older clients that still submit
  email on creation/retry must update. No backfill is included.

Focused verification uses Node 22 and local demo-project Firestore/Auth emulators:
`node --test test/account_deletion_join_requests.test.mjs test/account_deletion_matches.test.mjs test/account_deletion_worker.test.mjs test/firestore_rules.test.mjs`.
The next slice is bounded notification cleanup, using supported indexed UID
streams and the existing manifest, with its own checkpoints and ambiguity tests.

### Bounded notifications phase

`runNotificationsDeletionPhase` processes one page per trusted invocation and
advances only `notifications → ratings` after all streams are exhausted. There
is no dispatcher and no ratings or permanent Auth deletion in this handler.

* Sequential `recipientUid == uid` and `actorUid == uid` queries use document-ID
  ordering and automatic single-field indexes. Neither snapshots nor email
  identify actors. Deleting whole records also removes their private snapshots.
* The retained `matchCleanup` manifest is read one entry per call. Only entries
  with both `organized` and `future` true drain notifications via `matchId == id`.
  Parent matches are never queried or read; missing parents do not affect cleanup.
  Other manifest entries are skipped. No replacement notifications are created.
* `notificationsCheckpoint` stores `recipientAfter/Done`, `actorAfter/Done`,
  `manifestAfter/Done`, and `matchAfter`. Manifest progress stays behind the active
  entry until its notifications are exhausted. Pages contain at most 100 records;
  full pages require another query to establish exhaustion. Deletes and progress
  commit atomically with lease fencing before reads and immediately before writes.
  Fresh leases resume these cursors. `notificationsCutoff` pins the original
  admission time across calls; `deletionRequestedAt` is never written.
* Supported references are `recipientUid`, optional `actorUid`, and `matchId`.
  Present UID references must be valid UID strings. Legacy actor/event absence is
  accepted without inferring identity. Nonempty `eventId` records must agree with
  the current supported type and exact `type_matchId_eventId` document ID; IDs are
  compared by construction, never split on underscores or used to guess actors.
  Invalid references or conflicting event/match IDs preserve the entire page and
  block with `notifications-ambiguous-state` and `notificationsBlockedRecord`.
  Malformed manifest entries block likewise. Lifecycle/checkpoint corruption fails
  closed. Transient database failures use the existing sanitized retry behavior.
* Completion revalidates all stream exhaustion, lifecycle and lease state before
  recording the completion marker and transitioning. Marker recovery and completed
  phase replay preserve next-phase progress. No indexes or rules are changed;
  deletion infrastructure remains client-denied under existing rules.

Next small slice: bounded ratings cleanup with its own supported-reference,
aggregation, pagination and retry tests. Permanent Auth deletion stays deferred.

### Bounded ratings phase

`runRatingsDeletionPhase` processes one transactional page per invocation, then
advances only `ratings → verify` after all streams finish. It implements neither
verification nor permanent Auth deletion and has no automatic dispatcher.

* Given and received streams query the `ratings` collection group by `raterUid`
  and `ratedUid` equality, ordered by full document path. The existing `ratedUid`
  index is reused; collection-group ascending indexes are added for `raterUid`
  and `matchId`. No rating or contribution authorization rules change.
* One existing `matchCleanup` entry is read per manifest invocation. Entries with
  both `organized` and `future` true drain `ratings` via `matchId` equality; past
  or participant-only entries are skipped. No match scan is performed. Missing
  match documents do not prevent removal. Supported ratings require all three
  identity fields; this pass does not discover fieldless records by broad scans.
* `ratingsCheckpoint` contains `givenAfter/Done`, `receivedAfter/Done`,
  `manifestAfter/Done`, and `matchAfter`. Rating cursors are full document paths,
  including across match parents; manifest cursors are IDs. At most 100 ratings
  are processed, and the manifest cursor stays behind its active entry until it
  drains. Full pages require another read to prove exhaustion. `ratingsCutoff`
  pins the original cutoff; `deletionRequestedAt` is never rewritten.
* The existing deterministic contribution reconciler now exposes a bounded
  transaction plan used by both its trigger wrapper and the deletion worker.
  It rereads each rating, hashed-path contribution, target profile, barriers and
  parent match before any writes. Deletion plans force the desired contribution
  to zero using the same `ratingAggregateAfterDelta` accounting. Multiple ratings
  for one recipient accumulate against a single staged profile value, followed
  by one profile update. Missing profiles are never created. Existing profiles
  with zero totals normalize to count/sum/average zero, even if a rating had not
  yet contributed. Inconsistent baselines block rather than clamp totals.
* Rating deletes, contribution deletes, aggregate changes and checkpoint writes
  commit in the same lease-fenced transaction. No contribution tombstones are
  needed: delayed/duplicate triggers reread the absent rating and cannot restore
  its contribution. There are no contribution scans. Existing exact contribution
  baselines remain a prerequisite, enforced by the shared environment readiness
  gate; this slice does not migrate or repair old aggregate baselines.
* Supported paths are `matches/{matchId}/ratingRaters/{raterUid}/ratings/{ratedUid}`.
  Every live rating's three identity fields must agree with its path. Conflicting
  paths, fields, contribution identity/score, manifest data or aggregate baselines
  preserve the entire page and block with `ratings-ambiguous-state` plus
  `ratingsBlockedRecord`. Names and emails never participate. Lifecycle/checkpoint
  corruption fails closed. Transient failures retain durable progress and use the
  existing retry state; lost acknowledgements cannot double-decrement aggregates.
* Completion revalidates all stream checkpoints and lease/lifecycle state before
  writing the completion marker and transitioning. A fresh lease resumes saved
  paths; completed-phase replay preserves any verification checkpoint already set.

Focused validation uses Node 22, local demo Firestore/Auth worker tests, existing
rating contribution tests, relevant Functions emulator tests, and index assertions.
Next small slice: the bounded verification phase, checking deletion postconditions
and unresolved work before authorizing the existing `verify → deleteAuth` edge.
Permanent Auth deletion remains a separate later slice.

### Bounded verification phase

`runVerifyDeletionPhase(db, uid, lease)` is read-only toward application records.
It changes only verification progress/job status and advances `verify → deleteAuth`.
It does not invoke Auth or implement permanent deletion.

Each invocation validates the job, barrier and outbox UID/schema/exact cutoff,
ready/deleting statuses, completed Auth disable/revoke timestamps and ordering,
pinned phase cutoffs, absence of both profiles, and absence of prior unresolved
blocked-record markers. Verification checkpoint structure fails closed. Existing
blocked jobs cannot resume without trusted repair. `verifyCutoff` pins the existing
admission timestamp; `deletionRequestedAt` is never changed.

Every invocation executes eleven targeted `limit(1)` existence probes:

* Matches: `creatorUid == uid`, `createdBy == uid`, and `participantUids
  array-contains uid`. All owner references are rejected, including historical
  owners that should already have been anonymized. No date filter hides bad dates.
* Join requests: collection-group `userId == uid` and legacy `uid == uid`.
* Notifications: collection `recipientUid == uid` and `actorUid == uid`.
* Ratings: collection-group `raterUid == uid` and `ratedUid == uid`.
* Contributions: collection `raterUid == uid` and `ratedUid == uid`, including
  orphan contributions whose source rating has already disappeared.

One document-ID-ordered manifest entry is inspected per invocation. Its match
is fetched directly, and the deleting UID's legacy path-only join request is
checked directly, even when the parent match is absent. Future organized entries
also require empty join-request descendants and empty notification, rating and
contribution `matchId` queries, each `limit(1)`. Contributions use automatic
single-field collection indexes; they are never globally scanned. The only added
index is collection-group `joinRequests.uid`; all other indexes are reused. Rules
and client-denied infrastructure/contribution access remain unchanged.

Manifest matches must agree with the cutoff classification. Organized matches
must have the exact anonymous organizer, no supported creator identity/snapshot
fields, and future ones must be cancelled for `organizer_deleted`. Every deleted
player slot must be exactly `{ deleted: true, displayName: 'Deleted player' }`.
Other players must have valid, nonconflicting supported UID/userId identities;
none may identify the deletion subject. Participant projections must agree with
remaining identities. A preserved historical participant match must contain an
anonymous player slot. Unidentifiable legacy snapshots and tombstones carrying
extra email/level/name/UID fields fail closed. Unrelated players' snapshots remain
allowed; names/emails are never searched to infer identity. Missing match parents
are allowed only after their applicable descendant checks pass.

`verifyCheckpoint` stores `manifestAfter` and `manifestDone`. Cursor and numeric
checkpoint writes are lease-fenced and atomic. After manifest exhaustion, the
completion marker is committed; the existing transition helper rechecks global
absence, profiles, lifecycle and lease before advancing. Lost acknowledgements
resume safely, including completion-marker recovery. Same-lease replay after the
transition is a no-op. Each page has at most 16 limit-one queries plus seven direct
document reads; final transition adds the fixed eleven probes and five direct
reads. No invocation reads a full collection.

Sanitized `verify-*` failures block the job without deleting application records
or advancing the phase/cursor. Transient database errors use the existing sanitized
retry state. Global checks repeat each page; already inspected manifest records
rely on the existing barrier/rules and trusted-writer contract to prevent renewed
prohibited references. This is bounded verification of the supported schema and
retained manifest, not a fuzzy/global audit of unknown legacy records or arbitrary
concurrent Admin writes. Path-only requests outside known manifest parents and
contribution records lacking all supported identity fields are not globally
attributable by this design.

Focused tests use Node 22 and local demo Auth/Firestore emulators, covering the
verification handler, worker primitives and the added index declaration.
Next small slice: implement the separately fenced `deleteAuth` operation and its
idempotent completion handling. Scheduling/recovery remain deferred.
