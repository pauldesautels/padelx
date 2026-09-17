# Matchmaking, commitment, and AutoFill foundation

This payment-free beta foundation is server-authoritative. Clients invoke App
Check-protected callable Functions and can read only their own bounded request
and proposal projections. Canonical `matchmakingRequests`, `matchProposals`,
`matchmakingActiveOwners`, and `reliabilityEvents` remain server-only. The
user-facing product name is **Quick Match**; stored mode/status identifiers are
unchanged.

## Request modes and lifecycle

- `solo`: one eligible player enters the queue.
- `partner`: the owner names one partner; the request remains
  `awaiting_partner` until that player explicitly accepts.
- `autofill`: an organizer links an existing future match with vacancies.

Canonical request states are `awaiting_partner`, `active`, `matched`, `locked`,
`confirmed`, `paused`, `cancelled`, and `expired`. No translated label is
stored. One owner lock prevents concurrent duplicate active intent. Client
request IDs provide idempotent creation.

Availability contains one to five future UTC timestamp windows plus an IANA
timezone identifier. The timestamps are authoritative; timezone is retained
for correct presentation and future venue scheduling. Location matching uses
`countryCode + cityId`, never localized city display text. Display city/area
remain presentation fields. Supported travel radii are 5, 10, 20, and 25 km.

## Compatibility policy

Hard constraints are evaluated before ranking:

- current age, legal, profile, Auth, deletion, and enforcement eligibility;
- blocks in either direction;
- canonical city and mutually acceptable travel radius;
- overlapping availability;
- level difference no greater than 1.5;
- no conflicting confirmed match in the proposed window;
- partner integrity and four-player capacity.

Soft ranking uses level spread and preferred-side composition. Within each
bounded candidate page, an established server-authored Reliability percentage
is an additional priority signal; it is never a hard exclusion and a pair uses
its lower member priority. The internal compatibility score is never exposed
as a Match Quality percentage. Candidate reads are
bounded to 60 per attempt. Request creation drives an immediate deterministic
attempt; no permanently running worker is required for the beta foundation.

## Proposals and commitment

Compatible requests are claimed transactionally into a lobby proposal. Every
offered player starts in `offered` and may become `accepted`, `declined`, or
`expired`. Acceptance locks that source request's spot. A decline or expiry
releases only that source request (and its intact partner pair); already
accepted sources stay `locked` while one bounded replacement search runs.
The canonical match is not promoted until the lobby has four accepted unique
players. Decline and expiry are not cancellations, no-shows, or Reliability
penalties.

Offer duration is centralized as `quick-match-confirmation-v1`: five minutes
when the match starts within 24 hours, ten minutes at 24–72 hours, and fifteen
minutes beyond 72 hours. Initialization and matching do not wait on these
durations; they are reservation deadlines only.

General solo/partner proposals intentionally use `venueStatus: needed`. They
lock a compatible group but do not create a canonical match until a safe venue
is chosen. This avoids inventing a host, court, or exact address. AutoFill
proposals reuse an existing match and transactionally add accepted replacement
players without changing already confirmed participants.

## Private venue boundary

Request/proposal projections contain only city and optional area labels. A
promoted private/free court stores its exact address and coordinates in the
server-authored `matchPrivateVenues/{matchId}` document. Existing Firestore
rules permit only active, verified canonical match participants to read that
document. The public canonical match retains only approximate city/area data,
so exact private venue data is never exposed through discovery, notifications,
request views, proposal views, or Reliability events. Club/public venues keep
their public place identity and coordinates on the canonical match.

Both listed courts and custom private addresses carry a Places place ID. The
venue callable re-resolves that ID with the server-only
`GOOGLE_PLACES_SERVER_API_KEY`, rejects a client/server coordinate mismatch,
and uses the trusted address and coordinates for distance checks and protected
storage. Arbitrary client coordinates are never authoritative.

Promotion is deterministic and transactional. It revalidates all four players,
both-direction blocks, active commitments, request constraints, proposal expiry,
and confirmations before creating exactly one canonical match and confirming
every member lock. Organizer account deletion and canonical match deletion
remove an associated protected venue document.

## Reliability events and projection

The append-only server ledger records objective events only:

- proposal accepted, declined, or expired (the latter two never affect score);
- a server-promoted confirmed-match commitment;
- a confirmed participant removed before a future match;
- a future match cancelled.

Cancellation events retain the canonical scheduled time and one objective,
non-public lead-time category (`under_2_hours`, `2_to_6_hours`,
`6_to_24_hours`, or `over_24_hours`). They still carry no inferred blame,
score, no-show finding, or automatic enforcement consequence.

`objective-reliability-v1` derives a separate `reliabilityProfiles/{uid}`
projection. Future commitments do not count as completed evidence. A cancelled
commitment counts as resolved evidence; otherwise a commitment enters the
sample only once its scheduled time has passed. Fewer than five unique resolved
commitments displays `New player` with no percentage. Thereafter the score
starts at 100 and deducts 5, 10, 20, or 35 points for cancellations over 24
hours, 6–24 hours, 2–6 hours, or under 2 hours before start. A successfully
secured AutoFill replacement halves that event's deduction (rounded up).
Projection rebuilds inspect at most the 200 most recent objective events for
the player, so work remains bounded as history grows. The bounded public
projection exposes only status, percentage rounded to five
points, sample size, and policy version. Raw events remain unreadable.

`attendanceEvidence` is reserved as a server-only future seam. V1 does not
write or consume it and never infers a no-show from app activity, location, a
star rating, or one participant's unsupported claim. Corroboration and appeals
require a later product and safety decision. Reliability never automatically
suspends or bans an account. Future policy may consider high-confidence queues
or repeated severe behavior, but no punitive threshold exists in V1.

## Notifications

The trusted matchmaking service writes deterministic recipient notifications
for partner invitations, confirmation offers, AutoFill replacement offers, and
canonical match confirmation. Notifications contain no request location,
private address, coordinates, internal compatibility score, or other members'
identifiers. Opening an invitation or offer returns to the authoritative
matchmaking screen; a confirmed-match notification may open Match Details.

## Bounded operations

- A matchmaking state read returns at most 20 request projections and 20
  proposal projections for the authenticated user.
- One immediate matching attempt scans at most five 60-document candidate
  windows (300 canonical request reads). Compatibility checks occur before the
  bounded eligibility/block/commitment revalidation for a complete group.
- Recovery reads at most 50 expired proposals, 50 expired requests, and five
  active requests per scheduled invocation. Each of those five attempts keeps
  the same 300-candidate ceiling.
- Availability is capped at five windows; a canonical group is capped at four
  unique players; partner and AutoFill offers therefore have bounded member,
  block, projection, notification, and transaction writes.
- Promotion writes one canonical match, at most one protected venue, four
  request/owner projections per participant, and four deterministic
  confirmation notifications. Firestore transaction retries remain
  idempotent because proposal, match, event, and notification IDs are stable.
- A Reliability projection rebuild reads at most the latest 200 objective
  events for one player and writes one public projection.

## Account deletion

Deletion removes owned/member matchmaking requests, private projections,
owner locks, proposals, protected venues for cancelled organizer matches, and
the deleting user's Reliability events and Reliability projection. If a proposal is removed because one
member is deleting, unrelated source requests are released back to `active`
with their owner locks and projections repaired; they are not stranded in a
matched proposal that no longer exists. Historical canonical match handling
continues to follow the existing anonymization and retention policy.

## Deployment and minimum device validation

Staging rollout order is deliberately dependency-first:

1. `firebase deploy --only firestore:indexes --project padelx-staging`
2. wait until every new matchmaking index reports ready;
3. `firebase deploy --only firestore:rules --project padelx-staging`
4. configure the staging Functions secret `GOOGLE_PLACES_SERVER_API_KEY` with
   a server-only, Places-API-restricted key;
5. deploy the targeted matchmaking callables and lifecycle/recovery functions,
   then the Reliability projection trigger;
6. build the device-test client from the matching source revision.

The targeted Function set is `createMatchmakingRequest`,
`respondPartnerInvitation`, `cancelMatchmakingRequest`,
`respondMatchProposal`, `getMatchmakingState`, `resolveMatchmakingVenue`,
`recordMatchCommitmentEvents`, `recoverMatchmaking`, and the changed shared
account-deletion worker/dispatcher exports identified by the release diff.
`projectPlayerReliability` is also required. The Reliability event linkage
queries require the `matchId + type` and `uid + occurredAt descending`
composite indexes to be ready first.
No deployment is part of local validation.

Minimum physical validation uses disposable staging accounts and covers: four
Solo players through venue promotion; one consented partner pair plus two Solo
players; decline and authoritative expiry; private-court visibility for current
members only; club/public court promotion; app relaunch during Active Search
and Match Found; organizer AutoFill after a remote participant leaves; repeated
replacement until full; cancellation of AutoFill; English/es-MX; 320-point
layout and enlarged text; blocking/enforcement changes before acceptance; and
account deletion while a proposal is active.

No no-show is inferred. The safe Reliability projection may be shown on a
player profile and used softly within a bounded candidate page; it has no
payment or enforcement consequence.

## Future work intentionally excluded

- payments, deposits, refunds, transfers, wallets, payment state, or paid-match checkout;
- Reliability leaderboards, hard Reliability exclusions, or Match Quality scores;
- commercial court inventory or booking;
- private-address disclosure;
- moderator enforcement based on matchmaking behavior;
- automatic no-show detection.
