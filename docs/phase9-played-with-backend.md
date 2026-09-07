# Phase 9 Slice 2: Played With backend

The match document remains canonical. `projectPlayedWithMatch` reconciles every
match write, while `recoverPlayedWithProjection` runs a bounded, single-instance
scheduled sweep for matches that become complete solely through the passage of
time. The recovery cursor persists under `socialProjectionState` and advances
through at most 50 matches per invocation. Each completed sweep replays a
one-hour overlap. A first deployment starts at the overlap boundary, so this
slice does not perform a historical backfill.

Projection accounting is server-only:

- `playedWithMatchContributions/{matchId}` records which active identities have
  received the per-player completed-match contribution.
- `playedWithContributions/{hash}` records one distinct match contribution for
  an unordered pair.
- `playedWithPairs/{hash}` stores the pair count and extrema used to materialize
  the two directional `users/{uid}/playedWith/{otherUid}` documents.

All contribution and aggregate changes for one match are made in one Firestore
transaction. Replays are no-ops. Cancellation or a deletion barrier reverses
the prior contribution; if the removed match was an endpoint, two bounded
queries find the next first and last shared match. The projector checks the
private account document, public profile, and deletion barrier before adding
an identity. Exact Phase 8 anonymous placeholders never become identities.

## Manual index

The only new composite index is
`playedWithContributions(pairKey ASC, scheduledAt ASC)`. It supports both
bounded endpoint queries (ascending and descending traversal) used when a
match is added, rescheduled, cancelled, or excluded. No discovery or future
feature indexes are included.

The scheduler is exported but must not be deployed in this slice. Non-emulator
execution also requires the explicit
`PADELX_PLAYED_WITH_PROJECTION_ENABLED=true` gate. Production remains refused
by the existing backend environment safeguard.
