# Phase 8 scalability staging rollout

No migration or index deployment is performed by the repository tooling automatically.

1. Review the Cloud Functions in `functions/`, install their locked dependencies, and run their emulator tests before any deployment.
2. Review `firestore.indexes.json` and deploy the new indexes to the staging project only.
3. Wait until every index reports ready before releasing the matching client or rules.
4. Authenticate the Admin SDK explicitly for staging, then run the backfill without `--apply`:
   `node tool/migrate_phase8_scalability.mjs --project=<staging-project-id>`
5. Resolve every reported blocker. The tool refuses all writes when any blocker exists. Missing match coordinates require manual repair.
6. Review the project ID and queued count, then rerun with the explicit `--apply` flag. This writes participant/geohash projections and exact lifetime rating aggregates.
7. Rerun the dry run. It should report zero queued writes, proving idempotence.
8. Deploy the reviewed rating and geohash functions to staging before allowing new ratings or location edits.
9. Deploy the reviewed rules to staging, then release the client to staging.
10. Verify discovery, organizer and participant history, pending requests, notification load-more, profile history, and lifetime ratings with verified and unverified accounts.
11. Inspect staging reads, function errors, and aggregate reconciliation before considering production.

`participantUids` is a convenience projection for queries. Match `creatorUid`/legacy `createdBy` and the `players` list remain authoritative. Security rules require all new and membership-changing writes to keep the projection synchronized. Legacy matches remain readable directly, but user-history queries will not find them until the backfill is complete.

Discovery queries only geohash cells intersecting the selected radius, with `scheduledAt >= now` and an initial 10-document per-cell page. Each query requests one look-ahead document, allowing the client to know whether that cell really has another page. Precision 4 is used for 25 km and precision 3 for wider searches to cap fan-out; exact distance removes bounding-box false positives. Every intersecting cell participates in every pass. If exact-distance filtering leaves fewer than the 12-result first-page target and at least one cell has another document, the client performs one bounded 20-document-per-cell retry. “Load more nearby matches” increases the per-cell window in 10-document increments, so dense cells do not permanently hide later matches. The trusted match trigger maintains both geohashes because Firestore rules cannot recompute a geohash safely.

Public profiles store `ratingCount`, `ratingSum`, and `ratingAverage`. The immutable-rating create trigger updates all three transactionally using Admin SDK privileges and creates an Admin-only event marker in the same transaction, making event retries idempotent. Clients can read the lifetime count/average but rules prohibit them from changing any aggregate field. The migration recomputes these fields from every existing immutable rating and is the required reconciliation/backfill before rollout.
