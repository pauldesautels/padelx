# Phase 9 Slice 8 — profile avatars

Each user has at most one current avatar reference. The normalized object lives at
`profileAvatars/{uid}/avatar.jpg`; `avatarVersion` is an optional,
non-negative integer mirrored in `users/{uid}` and `publicProfiles/{uid}`. A missing
field or zero means no avatar. URLs, tokens, filenames, timestamps, and image metadata
are never stored in Firestore.

The client accepts JPEG, PNG, and WebP inputs up to 5 MB, decodes and center-crops them,
then writes a static 512×512 JPEG at quality 85. Re-encoding drops EXIF and animation.
It replaces the deterministic object first and then atomically updates both profile
documents with a cache-busting version. If that batch fails, retrying it recovers the
already-valid object and no orphan or missing reference is created. Removal clears both
references first and then deletes the object, so failure never leaves a profile pointing
to missing content; a delete failure is surfaced for retry.

Storage rules only match one UID-owned JPEG filename, enforce a 5 MB object limit,
and deny every other path. Reads require authentication, an existing public profile,
and no account-deletion barrier. Firestore-backed checks are evaluated by Storage
rules; server/Admin SDK cleanup remains trusted and bypasses these client rules.

Deletion-v2 must: create its barrier before identity cleanup; delete every object under
`profileAvatars/{uid}/` (including a recoverable failed-cleanup version); clear or remove
both avatarVersion fields; ensure no derived social payload stores an avatar URL/path;
verify the UID prefix is empty before permanent completion. Historical match snapshots
contain no avatar fields and deleted identities continue to render the generic fallback.

Future work may add reporting/moderation. This slice deliberately provides no gallery,
original upload retention, SVG/GIF support, or media messaging.
