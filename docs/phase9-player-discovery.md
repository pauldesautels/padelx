# Phase 9 Slice 7: player discovery

## Scope and query

`discoverPlayers` derives country and city from the authenticated viewer's private profile and queries only
`publicProfiles` where `discoverable == true`, `countryCode == viewer.countryCode`, and
`cityId == viewer.cityId`. `cityId` is the stable provider place ID captured by the city selector; `city`
remains localized display text. Legacy viewers without `cityId` retain the previous exact `city` query until
they explicitly reselect their city or are backfilled. Canonical and legacy records are never guessed or
fuzzily combined. The Firestore-backed order is ascending `displayName`, then ascending public `uid`.
The opaque client cursor contains those two values and `startAfter` preserves that exact order.

Each request returns at most 20 players. It reads candidates in 60-document windows and inspects at most 120
candidates total. If the first window is sparse after policy/filter checks, the callable continues into the
second window. At the work cap it returns every eligible result found, a cursor for the last inspected
candidate, and `hasMore == true` when another candidate exists. End-of-query returns `hasMore == false`.
The client always exposes continuation when `hasMore` is true, even after an empty visible page.

## Filter semantics

- Area is an optional canonical `areaId` refinement when selected from Places. Legacy area selections retain
  their previous case-insensitive display-label refinement until replaced.
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
