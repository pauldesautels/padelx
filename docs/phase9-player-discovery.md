# Phase 9 Slice 7: player discovery

## Scope and query

`discoverPlayers` derives country and city from the authenticated viewer's private profile and queries only
`publicProfiles` where `discoverable == true`, `countryCode == viewer.countryCode`, and
`city == viewer.city`. The Firestore-backed order is ascending `displayName`, then ascending public `uid`.
The opaque client cursor contains those two values and `startAfter` preserves that exact order.

Each request returns at most 20 players and reads at most 60 candidate profiles (plus one existence probe).
Area, level, side, and relationship filters are applied after this bounded query. A sparse filtered page is
therefore expected and the backend never scans the rest of a city to fill it.

## Filter semantics

- Area is an optional case-insensitive exact refinement inside the viewer's city.
- Level is an optional exact match against the existing public level value.
- Left includes `left` and `either`; Right includes `right` and `either`; Either only includes `either`.
- Relationship can be Everyone, accepted Friends, or Played With (positive completed-match count).

The client cannot choose another city or country. A viewer without a usable country/city receives a safe
no-location response and no broad query is performed.

## Security and privacy

The callable uses the existing environment-guarded trusted Firestore instance, verified authentication,
active-viewer/deletion-barrier checks, and callable App Check enforcement. Every candidate is checked for an
active user record, deletion barrier, and blocks in both directions. Missing, legacy, malformed, or
non-discoverable public profiles are silently omitted.

The response is constructed from an explicit allowlist: UID, display name, level, preferred side, coarse
country/city/area, aggregate rating/match counts, and minimal relationship state. It never returns email,
coordinates, exact address, Places IDs, deletion state, block direction, friendship IDs, source match IDs, or
private user data. No Firestore client list permission was added.

There is a 750 ms per-instance per-viewer throttle. It complements App Check and the hard request/query caps
without introducing persistent discovery or rate-limit documents.

## Deletion and future work

This slice creates no persistent documents, so it adds no UID-bearing data requiring deletion-v2 cleanup.
Deletion barriers take effect on every request before a candidate is returned. Existing accounts missing any
required discovery field remain usable but do not appear until they update their profile; no backfill is used.

Profile photos can be a separate next slice after a Storage path, upload validation, moderation/default
behavior, public projection, rules, deletion cleanup, and privacy review are designed together.
