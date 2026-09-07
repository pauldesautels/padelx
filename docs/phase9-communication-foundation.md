# Phase 9 Slice 5: Communication foundation

## Model and lifecycle

`conversations/{conversationId}` is canonical and server-owned. It stores `type`, bounded
`memberUids`, optional `matchId`/`friendshipId`, server timestamps, a 140-character private
preview, `lastSenderUid`, and `schemaVersion`. Messages live at
`conversations/{conversationId}/messages/{requestId}` with `senderUid`, plain `text`,
`createdAt`, and the replay key. User-owned projections live at
`users/{uid}/conversationViews/{conversationId}` and hold list metadata, `unreadCount`, and
`lastReadAt`; clients access them only through bounded callables.

Direct IDs are a SHA-256 digest of the sorted UID pair. Match IDs are a SHA-256 digest of
the match ID. This guarantees one conversation per relationship or match without exposing
raw IDs in conversation document names.

Match chat is available to the organizer and current canonical players. Pending, declined,
unrelated, deleting, and removed players are denied. A player leaving a future match loses
read and send access immediately; this privacy-first choice avoids retaining access to later
logistics. A cancelled/deleted match is read-only to its conversation's last legitimate
member snapshot. A completed match accepts sends through 24 hours after `scheduledAt`, then
becomes read-only. The organizer can create/chat immediately, and newly approved players are
added when they first ensure/open the match conversation.

Blocks deliberately do not affect an existing shared match chat: confirmed participants
retain logistics access until the ordinary match cutoff. This is the narrow match-safety
exception. Blocks in either direction make a direct conversation direction-neutrally
inaccessible and remove it from the normal list. Unblocking alone does not restore sends;
an accepted canonical friendship is required. Unfriending preserves readable direct history
for both active participants but disables sending with neutral UI.

## Security, bounds, and notifications

Every operation is callable-mediated with Auth, verified email, active/deletion-barrier,
profile, App Check, and backend-environment checks. Sends transactionally recheck canonical
friendship/block/account state or current match membership/lifecycle. Firestore rules deny all
client access to canonical conversations, messages, conversation views, and rate documents.
Message text is trimmed, whitespace-only messages are rejected, and the limit is 1,000 Unicode
code points. Request IDs are deterministic/reusable and message document creation is idempotent.
The per-sender limit is 20 accepted messages per rolling one-minute window.

Message pages are newest-first, default 40 and maximum 50. Conversation pages default and
maximum 20; the server scans at most 61 projections to direction-neutrally filter inaccessible
direct threads. Public profile and match display data is batch-loaded in chunks of 30. Only
single-field descending timestamp indexes are used, so no new composite index is required.

Unread increments and preview changes share the send transaction. Mark-read resets the
per-user counter and advances `lastReadAt` transactionally. One coalesced notification per
conversation/recipient (`message_{conversationId}_{uid}`) is updated instead of appending a
notification per message. No push notification is sent.
Friend-request and friend-accepted events use the same server-owned, deterministic/coalesced
notification mechanism and link to the Friends surface.

## Deletion-v2 contract (not implemented in this slice)

Deletion-v2 must tombstone or remove every authored message body for both direct and match
messages, and remove the deleted UID's identity linkage. UID-bearing locations to clean or
verify are: conversation `memberUids` and `lastSenderUid`; message `senderUid`; direct
conversation `friendshipId` (pair-derived linkage); conversation-view owner path and
`otherUid`; notification `recipientUid` and `actorUid`; rate-limit document owner path; and
any match/friendship records already covered by their existing deletion phases. It must also
remove projections, unread state, notifications, and orphaned conversations where applicable.
The existing deletion ordering is intentionally unchanged.
