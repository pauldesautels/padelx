# Phase 9 Slice 6 — Play Again

Play Again creates a normal upcoming match first, then calls the protected
`createPlayAgainInvitation` operation. It never creates membership or a join
request. The invitee opens match details and uses the existing Request to Join
flow; the organizer must approve normally.

## Invitation lifecycle

Invitations live at `matches/{matchId}/invites/{inviteeUid}`. The deterministic
path and notification ID (`play_again_invite_{matchId}_{inviteeUid}`) make
retries idempotent. A dismissed invitation cannot be recreated for the same
match. A different match can always carry a new invitation.

`joined` means the invitee appears in the canonical match `players` membership,
so it changes only after organizer approval. The match-write reconciler removes
the notification when membership is confirmed, or when the match is cancelled,
full, or no longer upcoming. Dismissal changes the invitation to `dismissed` and
removes its notification. Dismissal does not alter normal match discovery.

## Authorization and limits

The callable requires verified authentication, App Check outside the emulator,
the environment guard, active/non-deleting accounts, no block in either
direction, organizer ownership of an open upcoming match, capacity, and no
existing membership. Eligibility comes from an accepted canonical friendship
or the server-owned Played With projection. A supplied source match must be a
non-cancelled completed match containing both people.

Limits are three pending invitations per match, twelve newly created Play Again
invitations per organizer in a rolling 24-hour window, and one invitation per
target per match. No bulk endpoint exists.

## Deletion-v2 references

Future deletion cleanup must handle:

- `matches/{matchId}/invites/{inviteeUid}`: document path UID plus `inviterUid`,
  `inviteeUid`, and optional `sourceMatchId` fields.
- `notifications/play_again_invite_{matchId}_{inviteeUid}`: recipient and actor
  UIDs, plus the invitee UID embedded in the deterministic ID.
- `playAgainRateLimits/{inviterUid}`: organizer UID in the path and
  `inviterUid` field.

No email, display name, bio, avatar, level, location, or message-body snapshot is
stored on the invitation.
