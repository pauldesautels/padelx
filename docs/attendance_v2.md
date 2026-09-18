# Attendance V2 beta foundation

Attendance V2 is prospective and payment-free. Historical matches are not backfilled. It records private participant attestations after a match and converts only conservative, server-adjudicated outcomes into the existing Reliability event ledger.

## Timing and commitments

The server opens submissions two hours after `scheduledAt` and closes them 72 hours later. Server time is authoritative; TTL is not used. Quick Match players become committed when they accept and enter the final canonical roster. An AutoFill player becomes committed only after accepting and joining that roster. For manual matches, the organizer's creation and an approved participant's final membership are the commitment boundary. Cancelled matches never open attendance.

## Evidence and adjudication

Each observer submits once per match. Server-only evidence is deterministic per match, observer, and subject. The client cannot nominate an observer or a subject outside the final roster. A result becomes final when every expected participant submits or the window closes.

Two independent statements that the match happened are required. Two statements that it did not happen, with no contrary statement, resolve `match_not_played`. Conflicts resolve `disputed`; inadequate evidence resolves `insufficient_evidence`. For a played match, attendance requires two peer confirmations, or one peer confirmation plus self-attestation with no contrary peer. A no-show requires two peer absence claims and no positive peer contradiction. One negative claim is never enough. The organizer has no extra weight. Missing submissions are not absence evidence.

Self-attestation is useful positive evidence but cannot override two or more independent peer absence claims. Corroborated peer absence with no contrary positive peer resolves `no_show`, even if the subject claims attendance. A contrary independent positive peer produces `disputed`; self-attestation alone does not create that dispute.

Cancellation is authoritative and is never double-penalized. Final canonical membership means a departed player is excluded and an accepted replacement is evaluated instead.

## Reliability policy

Policy `objective-reliability-v2-attendance` retains the five-resolved-commitment threshold, the bounded 200-event projection, existing cancellation deductions (5/10/20/35), and successful-replacement mitigation. An established no-show deducts 50, greater than a very-late cancellation but bounded so one event cannot permanently destroy an account. Established attendance adds a resolved commitment without a deduction. Disputed, insufficient, and match-not-played outcomes have no score effect. Historical V1 commitments retain their prior completion semantics; V2 commitments require a resolved attendance or cancellation outcome. Reliability remains only a soft matchmaking ordering input.

## Privacy, deletion, and operations

Raw evidence, submissions, and resolutions are server-only. They contain no venue, coordinates, messages, ratings, blocks, or safety-report content. Public surfaces receive only the existing bounded Reliability projection. Account deletion removes evidence observed by or about the user, submissions, resolutions containing the user, and the existing Reliability ledger/projection under the current deletion workflow.

Operators diagnosing disputes must use privileged server tooling, avoid exposing observer identities, and preserve an audit trail for any future correction. No generic correction endpoint is exposed in this phase. A correction service should require privileged claims, an explicit reason and timestamp, append an audit record, replace the resolution through a narrow operation, and rebuild Reliability deterministically.

Collusion cannot be eliminated by peer corroboration. There is no GPS/venue check-in, booking/payment proof, automatic enforcement, public appeal UI, or attendance push reminder. Repeated-voter analysis and administrative correction remain reviewed future seams. Raw evidence retention duration requires legal/operations review; TTL remains disabled. Counsel should review collection of attendance claims, Reliability use/visibility, disputes, deletion, and retention before public launch. Existing legal versions are unchanged.

## Validation status

Physical staging validation covers the attendance UI, a real physical submission, normal-attendance corroboration and final resolution, the positive Reliability sample, AutoFill final-roster behavior, and absence of private venue data from evidence. A second uncontaminated match was not naturally inside the submission window, so one-negative-claim fairness, corroborated no-show (including self-attestation precedence), independent-peer dispute, live cancellation precedence, and live account-deletion cleanup remain automated-only validation. Canonical timestamps were not altered to manufacture eligibility; these cases remain on the physical-validation checklist.

## Bounds and recovery

A four-player match creates one submission and four evidence documents per observer: at most 4 submissions and 16 evidence documents. Adjudication reads one match, at most 5 submission documents (the fifth detects malformed excess), and one resolution. It writes one resolution, one job state, at most four commitment events, and at most four outcome events. Reliability reads at most 200 events. Scheduled recovery runs every 30 minutes and examines at most 25 pending per-match resolution jobs per invocation. Completed jobs leave the pending query, preventing starvation; operations are idempotent.
