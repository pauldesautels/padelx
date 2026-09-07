# Phase 9 deletion-v2 and staging release gate

No command in this document has been executed against Firebase. Production
(`padelx-f168f`) is refused by the backend and tools.

## Deletion contract

New jobs are fixed at schema version 2 on admission and run:

`accepted → matches → joinRequests → social → messaging → notifications → ratings → storage → verify → deleteAuth`

Version 1 jobs retain exactly:

`accepted → matches → joinRequests → notifications → ratings → verify → deleteAuth`

The scheduler selects the phase table from the immutable job version. Barrier,
job, and outbox versions/cutoffs must agree. Unknown or mixed state fails closed;
checkpoints never imply phase completion.

The social phase reconciles every contributed match through the existing Played
With accounting transaction, then removes friendships and both projections,
blocks, residual friend/played-with views, invites in either role, and the
inviter quota document. It never creates relationships. Discovery has no durable
result records. The deletion barrier makes users disappear immediately.

Messaging replaces authored text with `Deleted message`, removes `senderUid`,
and sets `senderDeleted: true`. Direct conversations and both participant views
are removed after messages are neutralized. Match conversations retain surviving
logistics, remove the deleted member, and clear `lastSenderUid` when necessary.
Message and Play Again coalesced notifications are removed by the notification
phase. Rate-limit state is deleted.

Storage deletes only `profileAvatars/{uid}/avatar.jpg`. Not-found is success;
transient failure retries. The entire UID avatar prefix is checked with a
one-object probe before `storageVerifiedAt` is recorded. Final Firestore
verification uses one-result absence probes for all Phase 8 and Phase 9 identity
references. Historical match tombstones remain the Phase 8 `Deleted player`
shape. The barrier remains as a non-personal deletion receipt.

Staging discoverability defaults to **false** unless the source account already
explicitly opted in. This is safer than making legacy accounts discoverable for
testing. Avatar version defaults to zero; no object is backfilled.

## Guarded local/operator tools

The migration requires literal `--project=padelx-staging`, is dry-run by default,
uses one page per invocation, and writes its local checkpoint only with `--apply`.
Output contains summary counts only. `--validate-only` never writes. It backfills
profile defaults/coarse location and reconciles historical matches; it does not
create friendships, blocks, messages, or invitations.

The index checker is read-only, requires the same literal staging project, and
reports collection group, fields, scope, and `READY`, `CREATING`, or `missing`.

## Controlled staging rollout commands (do not run for production)

The required Functions/runtime flag matrix is:

| Staging stage | `PADELX_RATING_CONTRIBUTIONS_READY` | `PADELX_PLAYED_WITH_PROJECTION_ENABLED` | `PADELX_PHASE9_ENABLED` | `PADELX_ACCOUNT_DELETION_ENABLED` |
| --- | --- | --- | --- | --- |
| Before Phase 8 accounting is verified | `false` | `false` | `false` | `false` |
| Initial Phase 9 Functions deployment and index/rules validation | `true` | `false` | `false` | `false` |
| Backfill operator process only, after indexes are READY | `true` | `true` | `false` | `false` |
| Phase 9 social/messaging smoke tests | `true` | `true` | `true` | `false` |
| Disposable-account deletion exercise | `true` | `true` | `true` | `true` |

The backfill row applies only to the environment of the operator command. It
does not enable the deployed projector before aggregate validation. Never set a
later row until the preceding stage's checks pass.

Run from the repository root, in this order:

```sh
flutter analyze
flutter test
npm run test:deletion
npm run test:phase9
npm run test:rules
npm run test:storage
npm run test:phase9-safety
git diff --check

firebase deploy --project=padelx-staging --only firestore:indexes
node tool/check_phase9_indexes.mjs --project=padelx-staging
# Repeat the preceding read-only check until every required index is READY.

firebase deploy --project=padelx-staging --only firestore:rules
firebase deploy --project=padelx-staging --only storage

# Configure PADELX_PHASE9_ENABLED=false and PADELX_ACCOUNT_DELETION_ENABLED=false
# in the staging Functions environment before this deployment.
firebase deploy --project=padelx-staging --only functions

node tool/migrate_phase9.mjs --project=padelx-staging --page-size=50
node tool/migrate_phase9.mjs --project=padelx-staging --validate-only --page-size=50
# Review summary counts, then repeat the next command until nextStage=complete.
PADELX_RATING_CONTRIBUTIONS_READY=true PADELX_PLAYED_WITH_PROJECTION_ENABLED=true node tool/migrate_phase9.mjs --project=padelx-staging --apply --page-size=50 --checkpoint=.phase9-backfill-checkpoint.json

# Validate aggregates and indexes, then set PADELX_PHASE9_ENABLED=true while
# keeping PADELX_ACCOUNT_DELETION_ENABLED=false, and redeploy Functions.
firebase deploy --project=padelx-staging --only functions

flutter build web --release --dart-define-from-file=config/staging.json
firebase deploy --project=padelx-staging --only hosting

# After the full feature smoke test, set PADELX_ACCOUNT_DELETION_ENABLED=true
# and redeploy Functions before the disposable-account deletion exercise.
firebase deploy --project=padelx-staging --only functions
```

The final environment-variable changes use the team's approved secret/config
workflow; do not put a project-specific `.env` file or credentials in Git.

## Manual staging smoke checklist

- Social profile: save preferred side, frequency, bio, discoverability, country,
  city, and area; confirm public output contains only coarse approved fields.
- Played With: complete one match and then a repeat match; confirm directional
  lists, completed-match counts, repeat-player counts, idempotent replay, and a
  concurrent trigger/recovery reconciliation.
- Friends: request, reciprocal accept, explicit accept, decline, cancel, and
  unfriend; confirm canonical and both views agree.
- Blocking: block a friend, confirm friendship removal and mutual suppression;
  unblock and confirm no relationship or invitation is restored.
- Match chat: organizer and approved player can use it; pending player and future
  leaver cannot; completed-match grace works and later becomes read-only.
- Direct messages: only accepted friends can start/send; unfriend disables send;
  block disables access; unread, read, pagination, retry request IDs, and rate
  limits behave correctly.
- Play Again: invite a Played With target and a friend; deny a stranger; process
  invitation as a normal join request; approve it; grant chat only after approval.
- Players: confirm city scope, filters, pagination, blocking suppression, and
  omission when `discoverable=false`.
- Avatar: upload JPEG, replace, observe cache/version refresh, remove, reject
  cross-user access, and reject recreation after a deletion barrier.
- Deletion: populate one disposable account with friendships, Played With history,
  direct and match messages, invitations, notifications, avatar, and quota state.
  Delete it end to end. Confirm surviving aggregates exactly, authored message
  tombstones, no UID/social identity in every verified collection, no avatar
  object under its prefix, and permanent Auth deletion.

## Release gates

Before staging: all local suites and diff checks pass; every index is READY; tool
dry-run/validation counts are reviewed; a staging config and credentials exist;
Functions flags are confirmed disabled.

Before Phase 9 completion: the entire manual checklist passes, including the
fully populated schema-v2 deletion and schema-v1 recovery regression.

Before production: a separate authorization and production-ready change must
remove the explicit production refusal, repeat the index/rules/backfill rollout,
review privacy/legal retention policy, establish monitoring and rollback, and
complete a production change review. This release-gate implementation does not
authorize or perform that work.
