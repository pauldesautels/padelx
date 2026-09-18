# PadelX legal/policy product-accuracy review

Status: product-accuracy audit plus locally implemented v2 draft package. The authoritative repository policy drafts use `terms-beta-v2`, `privacy-beta-v2`, and `community-beta-v2`. The static policies and required backend versions have been deployed to staging, and the explicit V1-to-V2 re-acceptance path has passed physical staging validation. They have not been deployed to production and are not counsel-approved. This is not legal advice, does not establish legal compliance, and does not replace jurisdiction-specific counsel before public launch.

Labels used throughout:

- **VERIFIED CURRENT PRODUCT BEHAVIOR** — established from current repository code, rules, tests, or current operational documentation.
- **PROPOSED FACTUAL CORRECTION** — draft wording intended to correct an objective product mismatch.
- **PRODUCT DECISION REQUIRED** — a policy/product choice the repository does not settle.
- **LEGAL/PRIVACY REVIEW REQUIRED** — counsel or privacy review is necessary.
- **STORE DISCLOSURE LATER** — prepare for Apple/Google review, but do not make a final platform declaration yet.

## A. Executive legal/product-accuracy assessment

The previously deployed v1 beta policies were no longer fully product-accurate. Their most direct contradictions were that the Terms said PadelX did not offer automatic matchmaking and the Community Guidelines said Reliability did not exist. The local v2 drafts now correct those statements and disclose Quick Match, team assignment, confirmation and replacement flows, objective Reliability, private post-match Attendance evidence, private-court access boundaries, push-delivery records and release Crashlytics processing.

The local English and es-MX v2 drafts are substantively parallel. Duplicated in-app Guidelines now describe current Reliability and Attendance, and Spanish 18+ presentation uses “personas de 18 años o más” rather than wording that could exclude users who are exactly 18.

Approved product decisions are reflected in the v2 drafts and staging validation. Public-launch approval still requires review of jurisdiction-specific requirements, controller/operator presentation, retention, Attendance correction rights, provider roles and transfers, governing law/disputes, and material-change/re-acceptance obligations.

## B. Legal/policy surface inventory

| Surface | Repository source | Role / authority finding |
| --- | --- | --- |
| English Terms | `web/terms/index.html` | Authoritative current local draft; `terms-beta-v2`. |
| es-MX Terms | `web/es-MX/terms/index.html` | Public localized equivalent; same version. |
| English Privacy | `web/privacy/index.html` | Authoritative current local draft; `privacy-beta-v2`. |
| es-MX Privacy | `web/es-MX/privacy/index.html` | Public localized equivalent; same version. |
| English Community Guidelines | `web/community-guidelines/index.html` | Authoritative current local draft; `community-beta-v2`. |
| es-MX Community Guidelines | `web/es-MX/community-guidelines/index.html` | Public localized equivalent; same version. |
| Account deletion pages | `web/account-deletion/index.html`, `web/es-MX/account-deletion/index.html` | Public explanatory pages; not separately versioned. |
| In-app Community Guidelines | `lib/safety_policy.dart`, ARB localization keys | User-facing duplicate/explainer; currently stale on Reliability. |
| Help & Safety | `lib/settings_screen.dart`, `lib/safety_policy.dart`, ARBs | In-app safety guidance, support and blocked-player access. |
| Legal configuration | `lib/legal.dart` | Operator/contact, versions, locale-aware public URLs. |
| Acceptance client/gate | `lib/legal_acceptance.dart`, `lib/main.dart` | Server-authoritative acceptance check and blocking gate. |
| Acceptance backend | `functions/legal_acceptance.js` | Exact versions, validated acknowledgement, timestamped receipt. |
| Rules | `firestore.rules` | Acceptance records are server-only; protected product data requires authenticated/eligible access. |
| Internal legal checklist | `docs/legal_review_required.md` | Explicit unresolved counsel requirements; not public policy. |
| Safety operations | `docs/beta_safety_operations.md` | Internal report, enforcement, retention-target and Attendance-dispute practice. |
| Product facts | `docs/matchmaking_foundation.md`, `docs/attendance_v2.md` | Current technical/product behavior; not accepted policy. |

No repository statement explicitly declares English legally controlling over es-MX. A controlling-language decision is therefore **LEGAL/PRIVACY REVIEW REQUIRED**.

## C. Current factual product baseline

**VERIFIED CURRENT PRODUCT BEHAVIOR**

- Quick Match automatically forms compatible four-player groups for Solo users or an explicitly consenting Partner pair. It considers eligibility, blocks, canonical city, mutually acceptable travel radius, overlapping availability, level range, schedule conflicts, party integrity, preferred-side/team composition, and established Reliability as a soft ordering signal.
- Quick Match uses expiring offers. Decline/expiry before acceptance is not a cancellation or Reliability penalty. Four acceptances and venue resolution promote one canonical match. Find Matches remains manual browsing; Create Match remains organizer-driven.
- Teams are assigned deterministically using level/side information; no promise of perfect competitive equality exists.
- Organizer-controlled AutoFill can search for compatible replacements after a confirmed vacancy. A replacement joins only after acceptance and authoritative revalidation.
- Reliability is distinct from skill and subjective star ratings. Server-authored events cover commitments, cancellation timing, successful replacement mitigation, and corroborated Attendance outcomes. Fewer than five resolved commitments displays New player; established users receive a rounded public percentage. Raw event history is private. Reliability softly orders compatible candidates and does not automatically suspend or ban.
- Eligible final-roster participants may submit one private post-match Attendance attestation. Resolution uses peer corroboration; one negative claim is insufficient, the organizer has no special weight, missing evidence is not absence, and app inactivity does not establish a no-show. Conflicting/insufficient evidence can remain unresolved. Attendance and safety reports are separate.
- Approximate city/area and travel radius support discovery/matching. Device location is requested only for nearby features; no background/continuous-location implementation was found. Places search sends search input and geographic/provider parameters. Exact custom private-court address/coordinates are kept in a protected record readable only by current verified match participants. Club/public venue data remains on the canonical match.
- Push registration stores a provider token, platform/app identity, locale, enabled state, and timestamps. Preferences control delivery. Server delivery receipts record processing/completion and aggregate send/failure counts. Payloads are deliberately generic. Push delivery is not guaranteed; final APNs/Android external setup is deferred.
- Crashlytics is disabled in debug and web builds and enabled for non-debug native builds. PadelX intentionally attaches environment and build number and records fatal Flutter/platform errors and selected nonfatal operations. Provider SDK collection beyond that is **UNKNOWN / EXTERNAL PROVIDER DOCUMENTATION REVIEW REQUIRED**.
- Account deletion is staged and recoverable. It disables/revokes Auth access, removes/neutralizes active identity-bearing data and integrates matchmaking, private venue, Attendance, Reliability, messaging, ratings, notification and push cleanup. Historical/audit/safety records may remain only according to current narrow architecture and unresolved retention policy.
- Reports, blocks and account enforcement exist but are separate systems. Report volume alone does not establish misconduct. Enforcement is explicit and audited. Blocking removes friendship, prevents normal social discovery/contact and cleans relevant pending invitations; it does not erase historical matches, messages, Reliability or Attendance records.
- Payments, Match Quality, analytics SDK collection, GPS Attendance, venue check-in, automatic no-show detection from inactivity, and automatic Reliability-only enforcement are not implemented.

## D. Exact stale/false statements

### D1. Automatic matchmaking denial

- **Files/section:** English/es-MX Terms, “Beta service / Servicio beta”.
- **Prior v1 wording:** “It does not currently provide payments or automatic matchmaking.” / “No ofrece pagos ni emparejamiento automático.”
- **Problem:** Payments remain absent, but Quick Match is automated matchmaking.
- **PROPOSED FACTUAL CORRECTION:** “PadelX does not currently process payments. Quick Match can automatically assemble compatible players, while Find Matches lets users browse available matches and Create Match lets organizers create matches.”
- **Review:** factual correction; counsel should review the resulting service-description change and re-acceptance implications.

### D2. Reliability denial

- **Files/section:** English/es-MX web Community Guidelines, “Safety and enforcement”; `lib/safety_policy.dart`; `guidelineReliabilityTitle/body` in English/es/es-MX ARBs.
- **Prior v1 wording:** “no Reliability feature currently exists” / “actualmente no existe una función de Confiabilidad”; prior in-app copy called it future functionality.
- **Problem:** Reliability is live, public in summarized form, affects matching priority, and consumes cancellation/Attendance outcomes.
- **PROPOSED FACTUAL CORRECTION:** “PadelX uses a separate Reliability status based on objective or corroborated activity in PadelX, such as confirmed commitments, cancellation timing, successful replacement and resolved Attendance outcomes. Reliability is not a skill rating or disciplinary finding.”
- **Review:** factual correction plus legal review for transparency and reputation impact.

### D3. Venue visibility overstatement

- **Files/section:** English/es-MX Privacy, “Location and providers”.
- **Prior v1 wording:** “Match venue information and coordinates are shown to authenticated users.”
- **Problem:** This is too broad for protected private venues; exact private details are participant-only. Public venue data and safe approximate location have different visibility.
- **PROPOSED FACTUAL CORRECTION:** “Approximate match location and public venue information may be shown as needed for discovery and participation. Exact private-court details are restricted to authorized participants in the confirmed match.”
- **Review:** factual/privacy correction; precise-location classification requires counsel review.

### D4. Spanish age wording

- **Files/section:** es-MX Community Guidelines and in-app `adultOnly`/`guidelineAdultsBody` strings.
- **Prior v1 wording:** “mayores de 18 años.”
- **Problem:** Commonly means older than 18, while the code and Terms permit users who are 18.
- **PROPOSED FACTUAL CORRECTION:** “personas de 18 años o más.”
- **Review:** factual translation correction; age policy itself is unchanged.

### D5. Incomplete data list presented as current inventory

- **Files/section:** English/es-MX Privacy, “Data we process / Datos que tratamos”.
- **Current:** Covers profiles, location, matches, messages, notifications, ratings, push identifiers and reports, but not Quick Match proposals/preferences, Reliability events/projection, private Attendance evidence/resolutions, deletion workflow state, push delivery receipts, or crash diagnostics.
- **Problem:** New material processing is omitted.
- **Proposed:** use the Privacy package in section G.
- **Review:** new processing disclosure and potentially material change; legal/privacy review required.

No policy claims that payments, Match Quality, analytics, GPS Attendance, or automatic enforcement exist were found.

## E. Missing disclosure inventory

| Behavior | Relevance | Recommended surface | Proposed treatment | Classification |
| --- | --- | --- | --- | --- |
| Quick Match automated selection | Expectations/automated recommendation | Terms + concise Privacy purpose + Help | High-level factors; no weights or guarantee | Factual correction + legal review |
| Team assignment | Expectations | Terms/Help | May assign teams using compatibility information; no equality guarantee | Factual correction |
| Reliability public summary and matching influence | Reputation/automated ordering | Terms + Privacy + explainer | Describe categories, New player, public summary, soft influence | Legal/privacy review |
| Private Attendance evidence | Sensitive reputation evidence | Privacy + Terms/Help | Private submissions, corroboration, unresolved outcomes, support limitation | Legal/privacy review |
| Exact private-court data | Precise/private location | Privacy + Terms/Guidelines | Participant-only use; host/participant responsibilities | Legal/privacy review |
| Push registration/receipts | Identifiers/communications | Privacy + Help | Device/notification identifiers, preferences, receipts, opt-out | Privacy review |
| Crash diagnostics | Technical/device data | Privacy | PadelX metadata vs provider SDK collection | Provider review |
| Staged deletion | Expectations/rights | Privacy + deletion page | Initiation vs completion; narrow retention exceptions | Legal review |
| Blocking limits | Safety expectations | Help/Guidelines | Future interaction restriction, not historical erasure or universal separation | Factual clarification |
| Notification expiry | Time-sensitive offers | Terms/Help | Displayed deadline and app state authoritative; delivery not guaranteed | Counsel review |
| False coordinated Attendance claims | Integrity | Guidelines | Prohibit knowing/coordinated manipulation, not good-faith disagreement | Product + legal decision |

## F. Proposed Terms revision package

### Beta service

- **CURRENT:** feature list denies automatic matchmaking.
- **ISSUE:** objectively false.
- **PROPOSED:** “PadelX supports profiles, player and match discovery, organizer-created matches, Quick Match, messages, social connections, ratings, Reliability, Attendance confirmations, notifications, reports, moderation and deletion. Quick Match may automatically assemble compatible players. PadelX does not currently process payments.”
- **RATIONALE:** accurate scope without promising availability.
- **REVIEW FLAG:** factual correction; legal review and material-change assessment.

### Quick Match and teams

- **CURRENT:** absent.
- **ISSUE:** users lack contractual-level expectations for automated selection, offers and team assignment.
- **PROPOSED:** “Quick Match may use availability, location and travel constraints, player level, party or partner requirements, Reliability and other compatibility information to identify players and assign teams. Matches, timing, team balance, venue availability and notifications are not guaranteed. Offers may expire at the displayed deadline; current in-app state determines whether an offer remains available.”
- **RATIONALE:** transparent without exposing weights or guaranteeing outcomes.
- **REVIEW FLAG:** legal/privacy review for automated recommendation language.

### Commitments, cancellation, Reliability and Attendance

- **CURRENT:** ratings and safety are generic; Reliability/Attendance absent.
- **ISSUE:** current commitment/reputation consequences are undisclosed.
- **PROPOSED:** “Reliability is separate from playing level and user ratings. It summarizes objective or corroborated PadelX activity, which may include accepted commitments, cancellation timing, successful replacement and resolved Attendance outcomes. Declining or letting an offer expire before commitment is not treated as a cancellation. Eligible participants may submit private post-match Attendance information. PadelX may use corroborated outcomes in Reliability; conflicting or insufficient evidence may remain unresolved. Reliability may influence matching priority, is not an attendance guarantee, and does not by itself automatically suspend or ban an account.”
- **RATIONALE:** user-relevant consequences with no permanent formula promise.
- **REVIEW FLAG:** legal review; product decision on formula detail, correction and appeals.

### Private venues and real-world safety

- **CURRENT:** general private-location warning.
- **ISSUE:** custom residential/private courts now have protected exact details and sharing responsibilities.
- **PROPOSED:** “A host who provides a private venue must be authorized to use and share it for the match. Participants must not misuse or redistribute private venue details. Exact private-court information is made available only as needed to authorized participants in the confirmed match. PadelX does not verify every person, venue or safety condition.”
- **RATIONALE:** reflects actual use and responsibilities without a security guarantee.
- **REVIEW FLAG:** legal/liability and safety review.

### User content

- **CURRENT:** profiles, avatars, listings and messages only.
- **ISSUE:** omits ratings, reports, Attendance submissions and user-entered venue descriptions.
- **PROPOSED:** add those categories, while making clear Attendance/report evidence is restricted rather than public.
- **REVIEW FLAG:** legal review of license/processing language.

### Moderation and support

- **CURRENT:** reports can lead to restrictions; appeals may be emailed.
- **ISSUE:** “appeals” may imply a formal guaranteed process not implemented.
- **PROPOSED:** “Users may contact support about a moderation, Reliability or Attendance concern. PadelX may review the information but does not promise that every outcome or score will be changed. Formal review and response commitments remain subject to published policy.”
- **REVIEW FLAG:** product decision and legal review; do not promise formal rights prematurely.

### Deletion

- **CURRENT:** narrow but nonspecific retention exceptions.
- **ISSUE:** does not explain staged processing or distinguish initiation from cleanup.
- **PROPOSED:** “A deletion request begins a staged process: access may be disabled before backend cleanup completes. Active identity-bearing data is removed or neutralized through that process. Limited historical, safety, audit, fraud-prevention, security, legal, provider-log or backup information may remain only where justified by the applicable policy and law.”
- **REVIEW FLAG:** legal review; completion timeframe and retention scope remain decisions.

## G. Proposed Privacy Policy revision package

### Data we process

- **CURRENT:** omits Quick Match, Reliability, Attendance, delivery receipts, deletion state and crash diagnostics.
- **ISSUE:** incomplete inventory.
- **PROPOSED:** add: “Quick Match preferences, availability, travel radius, invitations, offers and confirmation state; objective Reliability events and summarized projections; private Attendance submissions, evidence and resolutions; notification preferences, device and notification identifiers and delivery records; account-deletion workflow and audit state; and crash/error diagnostics in enabled release builds.”
- **RATIONALE:** reflects current processing.
- **REVIEW FLAG:** legal/privacy review; provider-side diagnostics remain externally reviewed.

### Automated matching and Reliability purpose

- **CURRENT:** “discovery” and “matches” only.
- **ISSUE:** automated recommendation/order not described.
- **PROPOSED:** “We use availability, approximate location and travel constraints, level, partner requirements, preferred side, schedule conflicts and Reliability where applicable to identify and prioritize compatible Quick Match candidates and assign teams. Reliability is a separate summary of objective or corroborated commitment activity; it is not a skill rating or an automatic enforcement decision.”
- **RATIONALE:** high-level transparency without proprietary weights.
- **REVIEW FLAG:** privacy/counsel review for launch jurisdictions.

### Visibility

- **CURRENT:** public profile/rating wording omits Reliability.
- **ISSUE:** verified users may see New player or a Reliability percentage; raw history is private.
- **PROPOSED:** “Other authenticated users may see a summarized Reliability status or percentage. Raw Reliability events and private Attendance submissions are not displayed publicly.”
- **REVIEW FLAG:** legal/privacy review of reputation data.

### Location and providers

- **CURRENT:** implies all venue coordinates are visible to authenticated users.
- **ISSUE:** fails to distinguish approximate discovery data, device location, public places and protected private venues.
- **PROPOSED:** “PadelX processes a selected city and optional area, provider place identifiers, selected coordinates and travel radius for discovery, Quick Match and venue selection. When you invoke nearby features, the app may use current device location; the current implementation does not continuously track background location. Search input, country, session information and geographic bias may be sent to Google Places. Public venue details may appear with a match. Exact custom private-court address and coordinates are stored to operate a confirmed match and are restricted to authorized participants as designed.”
- **RATIONALE:** accurately separates location categories.
- **REVIEW FLAG:** precise-location/provider/legal review; do not promise absolute security.

### Attendance and Reliability

- **CURRENT:** absent.
- **ISSUE:** private peer evidence can affect a public reputation summary.
- **PROPOSED:** “Eligible final-roster participants may submit whether a match occurred and who played. These submissions and underlying evidence are restricted. PadelX uses corroboration; one negative submission alone is not conclusive, missing app activity is not a no-show, and conflicting or insufficient evidence may remain unresolved. Resolved Attendance outcomes may affect Reliability. Attendance evidence is separate from safety reports and does not automatically create account enforcement.”
- **RATIONALE:** meaningful fairness/privacy transparency.
- **REVIEW FLAG:** P0 legal/privacy review; correction, appeal and retention unresolved.

### Notifications

- **CURRENT:** only “push-device identifiers when configured.”
- **ISSUE:** omits app/platform identity, locale, preferences, timestamps and delivery receipts.
- **PROPOSED:** “When push is enabled, we process device and notification identifiers, device platform/application identity, delivery locale, notification preferences and registration/activity timestamps. We keep delivery records containing status and aggregate send/failure information to operate and troubleshoot notifications and remove stale registrations. Users may disable push in PadelX or device settings.”
- **RATIONALE:** minimal, understandable classification.
- **REVIEW FLAG:** privacy/provider review; no marketing-notification claim.

### Crash and error diagnostics

- **CURRENT:** absent.
- **ISSUE:** native release builds can send diagnostics to Crashlytics.
- **PROPOSED:** “In enabled native release builds, PadelX may collect crash and error diagnostics. PadelX intentionally attaches the app environment and build number and may record a sanitized operation label with an error. Firebase Crashlytics may collect additional technical information under its own service behavior; that provider-side collection must be reviewed against current provider documentation.”
- **RATIONALE:** separates known application metadata from unknown provider defaults.
- **REVIEW FLAG:** external provider documentation/privacy review required.

### Retention and deletion

- **CURRENT:** contains unenforced 90-day notification, 12-month evidence and 24-month audit targets.
- **ISSUE:** these are targets, not technical enforcement; newer Attendance/Reliability/deletion data has no approved duration.
- **PROPOSED:** preserve “target/not automated” qualification only if counsel approves public targets; otherwise replace with category-specific principles after decisions. Explain staged deletion and narrow retention exceptions without promising instant erasure.
- **REVIEW FLAG:** P0 retention and legal review.

### Service providers and sharing

- **CURRENT:** broad Firebase/Google/Apple reference.
- **ISSUE:** service purposes and data categories are unclear; jurisdiction-specific “sale/share” classifications are unresolved.
- **PROPOSED:** name service categories and purposes at a user-understandable level, without asserting contractual processor status not established.
- **REVIEW FLAG:** provider/DPA and jurisdiction review.

## H. Proposed Community Guidelines revision package

### Reliability section

- **CURRENT:** calls Reliability future/nonexistent.
- **ISSUE:** false.
- **PROPOSED:** “Reliability reflects objective or corroborated commitment behavior in PadelX and is separate from skill and subjective ratings. Do not attempt to manipulate Reliability, Attendance evidence, offers, cancellations or replacement outcomes.”
- **RATIONALE:** factual correction and integrity expectation.
- **REVIEW FLAG:** counsel/product review.

### Honest Attendance submissions

- **CURRENT:** malicious reports are prohibited; Attendance not addressed.
- **ISSUE:** coordinated false evidence is not covered clearly.
- **PROPOSED:** “Submit Attendance information honestly. Good-faith differences in recollection are not automatically misconduct. Do not knowingly fabricate or coordinate false Attendance submissions to manipulate another player’s Reliability.”
- **RATIONALE:** distinguishes disagreement from manipulation.
- **REVIEW FLAG:** product decision whether this becomes an explicit violation; legal review.

### Private locations

- **CURRENT:** prohibits exposing private residential locations.
- **ISSUE:** should also address authorized host sharing and participant redistribution.
- **PROPOSED:** “Only provide a private venue you are authorized to use and share for the match. Participants must not redistribute or misuse private venue details.”
- **RATIONALE:** current private-court feature.
- **REVIEW FLAG:** safety/liability review.

### Enforcement wording

- **CURRENT:** temporary suspension or persistent restriction; support “appeals.”
- **ISSUE:** warning policy and appeal guarantees are not finalized.
- **PROPOSED:** retain accurate suspension/ban capability, state that reports are reviewed and do not automatically prove misconduct, and route concerns to support without promising a formal appeal outcome.
- **REVIEW FLAG:** product/legal decision.

## I. Help & Safety / explanatory-copy recommendations

Non-contractual explanatory content should cover:

- A “How Quick Match works” explainer: factors, offer deadline, acceptance, venue coordinator, AutoFill, and app state as authoritative.
- A “Reliability” explainer: skill distinction, New player threshold, behavior categories, no public history, no attendance guarantee.
- An “Attendance confirmation” explainer: submission window, privacy, corroboration, unresolved outcomes, support contact and no guaranteed score change.
- A “Private courts” safety card: host authority, participant confidentiality, meeting precautions and emergency distinction.
- A blocking explanation: friendship removal and future social restrictions, but shared-match/historical records can remain.
- Notification help: permission/network/provider limitations and offer expiry.

These explanations should not create new rights, guarantees, retention periods or formulas beyond approved policies.

## J. Quick Match disclosure proposal

“Quick Match can automatically identify and group compatible players using information such as availability, approximate location and travel constraints, player level, party or partner requirements, preferred side, schedule conflicts and Reliability where applicable. Find Matches remains a separate manual browsing feature, and organizers can still Create Match. PadelX does not guarantee that a match will be found or that every proposed match will proceed.”

## K. Team-balancing disclosure proposal

“PadelX may assign teams using available level, preferred-side and party information. Team assignments are intended to support a playable match but do not guarantee equal ability or outcome.”

## L. Reliability disclosure proposal

Reliability measures commitment behavior, not playing skill. It uses server-authored objective or corroborated categories including accepted confirmed commitments, cancellation timing, successful replacement, established Attendance and established no-show outcomes. Offer decline/expiry before commitment is not a cancellation. Fewer than five resolved commitments is shown as New player; after that a bounded summarized percentage may be visible to authenticated users. Reliability may softly influence Quick Match ordering, but does not guarantee attendance and does not automatically suspend or ban. Raw event history is private. Exact numerical weights should remain unpublished unless product and counsel decide that greater formula transparency outweighs contractual rigidity/manipulation risk.

## M. Attendance/no-show disclosure proposal

Eligible final-roster participants may submit one post-match confirmation about whether the match happened and who played. Raw submissions/evidence are restricted. Current policy uses peer corroboration: one negative claim alone is not conclusive; organizer evidence has no special weight; missing submissions or app inactivity are not no-show proof; conflicting/insufficient evidence may remain unresolved. Resolved outcomes may affect Reliability but are separate from safety enforcement. Users may contact support about concerns, but no public appeal UI or guaranteed correction outcome currently exists.

Fairness, collusion, correction, retention and transparency require legal/product review. Detailed methodology belongs primarily in Help & Safety or a Reliability explainer, with core consequences summarized in Terms/Privacy.

## N. Private-location disclosure proposal

PadelX processes manually selected city/area, stable place identifiers, selected coordinates, travel radius, current device location when a nearby feature is invoked, public venue information, and exact custom private-court data. Approximate location supports discovery and matching. Exact private-court details support a confirmed match and are restricted to current authorized participants. Google Places receives search text and relevant country/session/geographic request information. No continuous/background tracking was found. Provider attribution/privacy-link requirements remain external legal/provider review.

## O. Push-notification disclosure proposal

When enabled, PadelX processes device and notification identifiers, device platform/app identity, locale, preferences, registration/activity timestamps, and delivery status/count records to deliver time-sensitive match notifications, respect preferences, troubleshoot delivery and remove stale registrations. Users may opt out through PadelX and device settings. Offers can expire, and delivery depends on permissions, network, device and provider availability; current in-app state is authoritative. No delivery guarantee or marketing-notification claim should be made.

## P. Crash/error-reporting disclosure proposal

**Known PadelX metadata:** native non-debug builds enable Crashlytics, attach environment/build number, record fatal Flutter/platform errors, and may record selected nonfatal errors with a sanitized operation label. Debug/web collection is disabled by application code.

**UNKNOWN / EXTERNAL PROVIDER DOCUMENTATION REVIEW REQUIRED:** device, OS, installation, stack, network, IP or other technical data automatically collected by Firebase Crashlytics; provider retention and international processing. Public wording must not claim PII collection is impossible.

## Q. Firebase/service-provider inventory

| Service | Purpose | Data plausibly sent from implementation | Current coverage | Review |
| --- | --- | --- | --- | --- |
| Firebase Authentication | Sign-in, verification, account control/deletion | Email, UID, provider/auth state | Generic Firebase/Auth mention | Provider/privacy/legal review |
| Cloud Firestore | Product records and projections | All stored application categories | Generic Firebase mention | Data-location/DPA review |
| Cloud Functions | Trusted operations/recovery | Auth/App Check context and operation data | Generic Firebase/Google mention | Provider/config review |
| Firebase Storage | Profile avatars | Image, owner path/metadata | Not explicit | Privacy/provider review |
| Firebase App Check | App attestation/abuse protection | Attestation/app/device-related technical data | Named as security control | Provider documentation review |
| Firebase Cloud Messaging | Push delivery | Provider token, generic notification payload, route IDs | Push identifier only | Provider/store review |
| Firebase Crashlytics | Native release diagnostics | Known environment/build/error plus provider-collected technical data | Missing | P0 provider/privacy review |
| Google Places API | City/area/venue search and validation | Search text, country, session token, geographic bias/restriction, place ID | Mentioned, broadly accurate | Attribution/provider review |
| Apple/device platform services | Apple sign-in/platform/location/push where used | Platform-dependent account, location or delivery information | Broad mention | External documentation review |
| Device location services | Nearby search | Current location when invoked | Covered | Permission/store review |

No Firebase Analytics dependency or application analytics SDK was found.

## R. Account-deletion findings

Deletion is asynchronous and staged. Acceptance immediately removes private/public profile and active eligibility/legal/enforcement state and begins Auth disable/revocation plus bounded cleanup. The worker handles social relationships/blocks, messaging identity neutralization, notifications, ratings, matchmaking requests/proposals/locks, protected venues where applicable, push devices/receipts, Reliability ledger/projection, and Attendance submissions/evidence/resolutions involving the user, followed by verification and Auth deletion. Historical matches and tombstoned/neutralized content needed for remaining users may remain under the current architecture.

Moderation actions and some safety/audit material may remain, but current code comments explicitly leave legal-receipt retention unresolved and delete the active acceptance record. Provider logs/backups are outside application cleanup. Policies must not promise instant universal erasure. Whether to state a completion timeframe, preserve pseudonymized acceptance, or define legal/safety holds is **PRODUCT DECISION REQUIRED + LEGAL REVIEW REQUIRED**.

## S. Retention decision matrix

| Data category | Current technical behavior | Current policy claim | Gap | Decision required | Legal review |
| --- | --- | --- | --- | --- | --- |
| Account/profile/avatar | Account-life; deleted through staged workflow | Generally account-life | Provider remnants/backup detail | Define exceptions | Yes |
| Messages/conversations | Sender identity neutralized; shared history may remain | Service/conversation lifecycle; neutralized | No binding duration | Decide duration/purpose | Yes |
| Matches/private venues | Historical match may remain; future/private identity cleaned as applicable | Anonymized history may remain | Exact boundaries/duration | Define historical retention | Yes |
| Notifications | Cleanup/deletion; no automatic 90-day job identified | 90-day target not automated | Public unenforced target | Implement or revise target | Yes |
| Push devices | Until unregister, invalidation or deletion | Identifier mentioned | No duration | Decide operational expiry | Privacy review |
| Delivery receipts | Completion records; deletion-integrated | Not specifically described | No duration | Decide expiry | Privacy review |
| Reliability events/projection | Up to 200 events used; deleted for deleting user | Missing | Retention/window distinction | Decide ledger duration | Yes |
| Attendance evidence/submissions/resolutions | Server-only; deletion-integrated; no TTL | Missing | No approved duration | Decide retention/correction hold | P0 |
| Reports/evidence | Open until resolution; targets documented, not enforced | 12/24-month targets disclosed as targets | Targets not enforced | Approve and implement/reword | P0 |
| Enforcement/moderation audit | Server-only historical actions retained | Broad exception | No binding duration | Define appeal/audit retention | Yes |
| Legal acceptance | Active receipt deleted during account deletion | Not explained | Whether pseudonymized receipt needed | Decide | P0 |
| Deletion jobs/receipts | Durable staged state/minimal completion receipt | Staged process stated | Duration after completion | Decide | Yes |
| Provider logs/backups | Provider lifecycle; app cannot fully erase directly | Provider lifecycle | Unknown exact terms | Review contracts/docs | P0 |

## T. Reporting/moderation/enforcement findings

Reports are private server records; message reports may include canonical message evidence, while match/player evidence is minimized. Review is privileged and redacts sensitive evidence by default. Enforcement can apply temporary suspension or persistent ban and records append-only moderation actions. Enforcement is not automatically derived from report count, reason, blocks, ratings, Attendance or Reliability. Reporter identity must not be promised absolutely anonymous; proposed wording should say access is limited and information is used for safety/moderation, subject to applicable legal process. Warning and formal appeal policies remain unresolved.

## U. Rating-system distinctions

- **PadelX level/skill:** controlled 1–7 scale used for profile/match compatibility; not guaranteed to measure ability perfectly.
- **Reliability:** objective/corroborated commitment behavior; New player or summarized percentage; soft matching input.
- **Subjective ratings:** five-star post-match user feedback; individual receipts private, aggregate average/count visible. Current Reliability code does not consume star ratings.

Policies should use distinct defined terms and never imply subjective ratings affect Reliability.

## V. Attendance vs safety-report distinction

Attendance evidence concerns whether a match occurred and who played. A safety report alleges conduct or safety/policy concerns. They use separate storage, review and consequences. A resolved no-show may affect Reliability but does not automatically create a safety report or enforcement action.

## W. Blocking findings

Blocking creates a directional block, removes friendship/views, prevents ordinary social discovery/contact, and best-effort dismisses relevant Play Again invitations. Bidirectional block checks exclude matching/discovery and communication paths. Unblocking does not restore friendship. Blocking does not delete historical messages, matches, ratings, Attendance, Reliability, safety records, or shared-match membership and cannot guarantee the users never encounter each other in every legitimate shared context.

## X. Age/eligibility findings

Code requires an affirmative 18-or-older assertion; it stores eligibility without date of birth or independent verification. Legal acceptance is separate. Terms and Privacy align at 18+, but Spanish Guidelines/UI “mayores de 18” should be corrected to “18 años o más.” The intended store audience, treatment of false age assertions, and possibility of receiving data from minors despite the gate require counsel/privacy review. Do not change the threshold without a product/legal decision.

## Y. Messaging/user-generated-content findings

UGC includes display name, avatar, bio, match information, messages/chat, subjective ratings, reports/evidence, Attendance submissions, and user-entered private venue descriptions. Direct and Match Chat messages are plaintext at the application layer and not end-to-end encrypted. Access is membership-based and reporting can copy limited message evidence for privileged review. No proactive comprehensive content monitoring was found; policy should not imply it. Deletion neutralizes sender identity where shared conversation integrity must remain.

## Z. Public-profile visibility findings

Verified users can read public profiles containing display name, avatar version, level, country/city/area labels and canonical place IDs, preferred side, play frequency, bio, discoverability and server aggregates. Find Players requires discoverable=true and other eligibility. Profiles remain reachable through legitimate matches/social/message/history contexts even when discovery is off. Subjective rating average/count and match aggregates may display. Reliability projection is separately readable to verified users and displayed as New player or percentage; raw history remains private. Exact private venue, email, push token, Attendance evidence, reports and blocks are not public-profile fields.

## AA. Complete current data inventory

| Category | Examples | Purpose | Visibility | Ownership | Deletion interaction | Retention | External service |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Account | email, UID, auth/provider state | Authentication/access | User/provider/server | Auth/provider | Auth disabled/revoked/deleted | Provider review | Firebase Auth |
| Profile | name, avatar, level, side, frequency, bio | Identity/discovery | Authenticated users for public fields | User input + server aggregates | Removed | Account-life target | Firestore/Storage |
| Location | city/area IDs/labels, coordinates, radius, device location | Discovery/matching/venues | Approximate/public as needed; exact private participant-only | User/device/provider/server validation | Active identity removed; match history policy applies | Review required | Places/device services |
| Matchmaking | availability, mode, partner consent, offers, confirmations, locks | Quick Match | Own bounded projection; canonical server-only | Server-authoritative | Removed/released | Operational lifecycle; no TTL | Firestore/Functions |
| Match | schedule, participants, teams, venue, chat link | Organize/play | Authenticated discovery or participants depending field | Organizer/server | Future participation removed; history neutralized | Review required | Firestore/Places |
| Messaging | conversations, plaintext messages, unread state | Communication | Conversation members | User/server | Sender neutralized; shared content may remain | Unspecified | Firestore/Functions |
| Social | friendships, blocks, invitations, shared history | Social controls | Owner projections/authorized calls | Server-authoritative | Removed | Operational/history-specific | Firestore |
| Skill/rating | level; star ratings, aggregate | Compatibility/feedback | Level and aggregates public; individual receipt private | User + server aggregate | Contributions removed/reconciled | Review required | Firestore/Functions |
| Reliability | events, status, percent, sample, policy | Commitment summary/matching | Summary verified-user visible; events private | Server | Events/projection removed | 200-event calculation bound, not retention | Firestore/Functions |
| Attendance | submission, evidence, resolution, job | Post-match corroboration | Server-only; participant state summarized | Participant input + server resolution | User-related records removed | Unknown / review required | Firestore/Functions |
| Safety/reports | reason, optional details, evidence, review state | Safety/moderation | Privileged only | User report + reviewer | May be retained under unresolved safety policy | Targets not enforced | Firestore/Functions |
| Enforcement/audit | suspension/ban, moderation actions | Access safety/audit | Server/privileged only | Authorized operator/service | Active state removed; history preserved | Unknown / review required | Auth/Firestore |
| Device/push | token, platform/app, locale, preferences, timestamps | Notification delivery | Server/owner settings | Device/user/server | Removed | Unknown | FCM/APNs/Firebase |
| Delivery receipts | status, type, recipient link, counts, timestamps | Idempotency/troubleshooting | Server-only | Server | Deletion-integrated | Unknown | Firestore/FCM |
| Crash/diagnostics | error/stack, environment, build, operation | Stability | Authorized project operators/provider | SDK/application | Provider lifecycle | Unknown | Crashlytics |
| Legal acceptance | versions, UID, acceptedAt | Gate/version proof | Server-only | User acknowledgement/server | Active record deleted | Counsel decision | Firestore/Functions |
| Deletion/audit | barrier, job, outbox, checkpoints, receipt | Safe staged deletion | Server/privileged | Server | Minimal completion lifecycle remains | Unknown | Auth/Firestore/Storage |

No payment-card/bank/payment transaction category exists.

## AB. English/es-MX parity findings

- Web Terms, Privacy, Guidelines and deletion pages have matching section structure and versions.
- Both languages repeat the same automatic-matchmaking and Reliability inaccuracies.
- English “18 or older” is mistranslated in some Spanish UI/Guidelines as “mayores de 18”; Terms/Privacy correctly use “al menos 18” / “18 años o más.”
- Quick Match should remain the product name in Spanish, as current UI does, with explanatory Spanish surrounding it.
- Reliability is consistently rendered as “Confiabilidad” in current UI, but the “future” label/description is stale in both languages.
- Attendance has localized current UI terminology, but no accepted-policy equivalent yet. Counsel/translator should choose consistent “confirmación de asistencia,” “inasistencia” and dispute terminology.
- English Community Guidelines omit the operator/contact introductory sentence that Spanish includes. This is a parity inconsistency, though contact still appears later in both.
- No controlling-language clause exists. A bilingual legal translator/counsel should review meaning, not just key parity.

## AC. Material-change matrix

| Change | Document | Factual correction? | New processing disclosure? | Rights/obligation change? | Potentially material? | Renewed acceptance review? |
| --- | --- | --- | --- | --- | --- | --- |
| Add Quick Match | Terms/Privacy | Yes | Yes | Expectations | Yes | Yes |
| Add Reliability | Terms/Privacy/Guidelines | Yes | Yes | Reputation/conduct | Yes | Yes |
| Add Attendance | Terms/Privacy/Guidelines | Yes | Yes | Evidence obligations | Yes | Yes |
| Correct private-location access | Privacy/Terms | Yes | Clarifies existing | Host/participant duty proposed | Yes | Yes |
| Add push records | Privacy | No stale claim | Yes | No | Possibly | Counsel review |
| Add Crashlytics | Privacy | No stale claim | Yes | No | Possibly | Counsel review |
| Clarify staged deletion | Terms/Privacy/deletion | Yes | Yes | Rights expectations | Yes | Yes |
| Correct Spanish age phrase | Guidelines/UI | Yes | No | No threshold change | Low but important | Counsel review |
| Add false Attendance manipulation rule | Guidelines | No | No | New explicit obligation | Yes | Yes |
| Clarify block limitations | Help/Guidelines | Yes | No | Expectations | Possibly | Counsel review |

## AD. Current legal version/acceptance inventory

- Terms: `terms-beta-v2` (previous deployed/accepted version: `terms-beta-v1`)
- Privacy: `privacy-beta-v2` (previous deployed/accepted version: `privacy-beta-v1`)
- Community Guidelines: `community-beta-v2` (previous deployed/accepted version: `community-beta-v1`)
- Schema: 1
- Effective public date: September 14, 2026.
- Versions are duplicated consistently in `lib/legal.dart` and `functions/legal_acceptance.js` and verified in tests.
- Signup requires 18+ confirmation before Auth creation. Legal acceptance is then checked for authenticated accounts, including existing users.
- The client submits all three exact versions, `acknowledged=true`, and an idempotent request ID to `recordLegalAcceptance`.
- The Function verifies active account/deletion/enforcement state, exact payload/version values, and writes server-authored `acceptedAt`.
- The gate performs an authoritative recheck. Matchmaking also requires current eligibility and legal acceptance.
- Firestore clients cannot directly read/write acceptance records.

## AE. Historical-user/re-acceptance analysis

If any version constant changes, an existing receipt no longer satisfies `getLegalAcceptance`; the gate will require acceptance of the new triplet before normal access. This provides current re-acceptance mechanics, but does not decide whether every proposed revision legally requires re-acceptance. Because Quick Match, Reliability, Attendance, precise/private-location handling and diagnostics are material additions, counsel/product should explicitly decide versions, notice and re-acceptance. No current record or version was changed by this audit.

## AF. Legal-entity finding

Terms say the agreement is with Paul Desautels, operator of PadelX, and Privacy says PadelX is operated for beta by Paul Desautels. The repository does not establish a finalized company/controller entity, physical address, DPO, representative or telephone number. This is a prominent **P0 BUSINESS + LEGAL COUNSEL DECISION BEFORE PUBLIC LAUNCH**. Do not invent an entity or address.

## AG. Governing-law/dispute-clause inventory

The current Terms explicitly say final governing-law, jurisdiction, statutory-rights, warranty, liability and dispute provisions still require legal review. There is no operative governing-law, forum, arbitration or class-action-waiver clause in the reviewed Terms. Launch jurisdictions and dispute framework are **P0 LEGAL COUNSEL REVIEW REQUIRED**.

## AH. Liability/safety disclaimer findings

Current material says participation arrangements are between users, urges judgment when meeting others/private locations, disclaims emergency-service status, and warns beta features may change. It does not comprehensively address sports injury, venue condition/availability, identity verification, team/match quality, private-host authority, third-party venues, or notification failure. Do not expand or weaken liability language without counsel. Help & Safety should still give non-contractual precautions for unfamiliar players/private homes and never imply every user/venue is verified.

## AI. Third-party/service-provider review requirements

Counsel/privacy review should verify current Google/Firebase/Apple terms, provider roles, DPAs, data regions/transfers, retention, subprocessors, Places attribution/privacy links, Crashlytics automatic collection, FCM/APNs processing, and store declarations. The policy should use neutral “service/infrastructure provider” wording unless contractual roles are confirmed. Jurisdiction-specific “sell” or “share” classifications are not determined by this repository audit.

## AJ. Product decisions still required

### P0 before launch

1. Final legal/controller entity and launch jurisdictions.
2. Attendance dispute/correction/support path and whether any outcome can be corrected.
3. Reliability transparency level, including whether exact weights remain private.
4. Category-specific retention policy, especially Attendance, reports/evidence, moderation audit, legal receipts and deletion jobs.
5. Whether coordinated knowingly false Attendance claims are an explicit Guidelines violation.
6. Support/review commitments and wording—informal concern versus formal appeal.

### P1 should resolve

1. Push token/receipt operational expiry.
2. Historical match/message retention boundaries.
3. Private venue host/participant responsibilities.
4. Whether high Reliability later receives benefits (not current behavior).
5. Public Reliability explainer detail.

### P2 future

1. Formal in-app appeal/correction tooling.
2. Future payments terms if payments are designed.
3. Future Match Quality disclosure if such a feature is implemented.

## AK. Counsel questions

### P0 before launch

1. Who is the contracting party/controller and what required contact details apply?
2. Which jurisdictions are in scope, and what governing-law/dispute/statutory-rights terms are required?
3. What lawful-basis/notice/rights treatment applies to public Reliability and private peer Attendance evidence?
4. What correction, contest, transparency or appeal rights/process must exist for Reliability/Attendance?
5. What retention periods and legal/safety holds are defensible and implementable?
6. How should precise/private residential venue data and Google Places processing be described?
7. What minors/false-age and intended-audience language is required?
8. What Firebase/Google/Apple disclosures, transfer terms and provider links are required?
9. Are the proposed changes material enough to require new versions and renewed acceptance?

### P1 should review

- Report confidentiality wording and moderator access.
- Suspension/ban/support-review commitments.
- Blocking expectations and shared-context exceptions.
- Crashlytics and push diagnostics disclosures.
- Sports injury, private venues, third-party venues, identity and notification disclaimers.
- Whether public retention targets should remain before automation exists.

### P2 future

- Payments, booking, deposits/refunds and provider terms.
- Match Quality or expanded automated decisions.
- Public formula/leaderboard or Reliability incentives.

## AL. Store-disclosure future checklist

### Apple

- Map verified inventory to App Privacy categories: contact identifiers, user content, precise/coarse location, identifiers, diagnostics and product interaction where applicable.
- Review Firebase/Google/Apple SDK manifests and Crashlytics/FCM/Places behavior.
- Confirm account-deletion URL and in-app deletion.
- Confirm Privacy, Terms and support URLs.
- Review location permission purpose strings and push usage.
- Do not declare analytics or payment data unless later implemented.

### Google Play

- Map the same inventory to Data Safety collection/sharing/purpose/ephemeral/optional fields.
- Review account-deletion URL and deletion representations.
- Review Firebase SDK and Places/Crashlytics/FCM data practices.
- Confirm target audience is adults and policy wording matches 18+ flow.
- Confirm user-content/reporting/blocking disclosures.

All platform answers remain **STORE DISCLOSURE LATER** pending provider documentation and final release configuration.

## AM. Public-URL readiness

Repository-hosted stable routes exist for `/privacy`, `/terms`, `/community-guidelines`, `/account-deletion` and es-MX equivalents. Hosting preparation copies and validates them, with explicit routes before the Flutter SPA fallback. Runtime requires a valid HTTPS `LEGAL_BASE_URL`; release configuration must point to the intended public domain.

- Privacy URL: v2 product-accurate content is deployed to staging; counsel approval remains required before public launch.
- Terms URL: v2 product-accurate content is deployed to staging; counsel approval remains required before public launch.
- Account deletion URL: route exists and describes in-app/support paths.
- Support URL: no dedicated support webpage was found; only `mailto:support.padelx@gmail.com`. Store suitability is a final-launch decision.

## AN. Policy source-of-truth / translation-maintenance finding

The public HTML files function as authoritative accepted documents, while in-app Guidelines/ARB content is a duplicated explanatory representation. No explicit source-generation pipeline or controlling-language declaration exists. Recommended workflow after approval: maintain one reviewed English policy source, a counsel-reviewed es-MX equivalent, generate/validate public and in-app representations where feasible, test headings/version/contact/required factual concepts, and require semantic bilingual review for each version. This recommendation does not choose a legally controlling language.

## AO. Exact review document created

`docs/legal_policy_revision_review.md` — this file only.

## AP. Validation plan/results

The audit sampled policy claims against `functions/matchmaking.js`, `functions/reliability.js`, `functions/attendance.js`, `functions/push_devices.js`, `functions/push_delivery.js`, `functions/account_deletion*.js`, `functions/blocks.js`, `functions/reports.js`, `functions/account_enforcement.js`, `lib/places.dart`, `lib/crash_reporting.dart`, `lib/legal*.dart`, `firestore.rules`, dependencies, localization resources, tests and current architecture documents. Final repository/diff checks are recorded in the task report. No claim of jurisdiction-wide compliance is made.

## AQ. Git status expectation

The intended checkpoint includes the complete product-accurate v2 policy, gate, localization, Hosting-preparation, environment-safe link, documentation and test workstream. The generated SwiftPM workspace directory remains excluded and untouched.

## AR. Safety confirmation

This review does not modify authoritative Terms, Privacy, Community Guidelines, Help & Safety, legal versions, acknowledgement mechanics, Firestore records, runtime behavior, Reliability, Attendance, matchmaking, notifications, deletion behavior or platform configuration. It does not contact counsel or configure external services.

## REVIEW NEEDED BEFORE PUBLIC LAUNCH

1. Global jurisdiction, controller/operator and required-contact presentation.
2. Governing-law, forum, dispute and liability framework.
3. Attendance/Reliability correction and contest rights beyond the approved support-based path.
4. Exact retention periods, legal holds and narrow safety/legal/audit exceptions.
5. Private-venue obligations and precise-location treatment.
6. Provider roles, transfers and store-disclosure positions.
7. Material-change notice and re-acceptance requirements.

## AFTER HUMAN/LEGAL APPROVAL

1. Approve product decisions.
2. Obtain legal/privacy review.
3. Finalize English policy text.
4. Finalize es-MX equivalent text.
5. Decide version increments.
6. Update authoritative policy sources.
7. Update in-app copies.
8. Update public/static copies.
9. Update legal acceptance constants.
10. Add/update policy-parity tests.
11. Validate re-acceptance flow if versions change.
12. Run full localization/static validation.
13. Physically verify legal screens.
14. Audit exact diff.
15. Create a checkpoint commit.
16. Deploy only after explicit authorization.

## IMPLEMENTATION STATUS — PRODUCT-ACCURATE V2 DRAFT

Approved product decisions have now been implemented locally: operator Paul Desautels; global launch intent without a universal-compliance claim; support-based Attendance/Reliability concern review without a guaranteed correction or deadline; behavior-category Reliability transparency without exact numerical weights; prohibition of knowingly false or coordinated Attendance manipulation while protecting good-faith disagreement; and retention wording that leaves exact periods unresolved.

Updated surfaces include the authoritative English/es-MX Terms, Privacy Policy and Community Guidelines; duplicated in-app Guidelines; client/backend legal-version requirements; localization; policy/gate tests; and legal-review documentation. Acceptance schema remains 1. Existing v1 and mixed receipts fail the exact v2 requirement; no acceptance is migrated automatically.

### COUNSEL REVIEW OUTSTANDING

Global jurisdiction requirements, governing law/forum/disputes, operator/controller presentation, exact retention, retained safety/audit legal basis, Attendance/Reliability correction rights, minors/18+ handling, provider roles and transfers, Crashlytics/FCM/APNs processing, precise/private-location obligations, sports and third-party venue liability, and material-change/re-acceptance requirements remain unresolved.

### FINAL STORE DISCLOSURE LATER

Apple App Privacy and Google Play Data Safety answers, provider manifests, production push configuration and final public support/privacy metadata must be completed from the approved launch configuration. No store work is part of this implementation.

### SAFE STAGING ROLLOUT AND ROLLBACK

Rollout must keep the public documents, backend-required versions, and client-required versions coordinated. Prepare and deploy Hosting first so the v2 documents are reachable; then deploy the legal-acceptance callables and every matchmaking function that imports the shared required-version constants; then rebuild the client with the intended legal base URL. No Firestore rules, indexes, schema migration, receipt backfill, or automatic acceptance is required.

Deploying the backend v2 requirement immediately makes existing v1 or mixed-version receipts non-current. Those users will be gated until they explicitly accept all three v2 documents. A rollback must restore the public documents, backend constants, and client constants as one reviewed set. Existing receipts must not be deleted or rewritten during rollback. Because the current receipt is one exact-version record, users who accepted only v2 would not satisfy a restored v1 requirement and could be asked to acknowledge again; this is a material rollback consequence that must be approved rather than hidden by an automatic migration.

### PHYSICAL STAGING VALIDATION

Physical iPhone validation passed for V1-to-V2 re-gating, disabled Continue before acknowledgement, opening all three V2 policies, explicit user acknowledgement, authoritative acceptance recheck, gate exit, relaunch persistence, and all four es-MX Settings legal links including account deletion.

Two P0 client defects were found and corrected during validation. The device-test build omitted `LEGAL_BASE_URL`, so relative policy paths produced no launchable URI; legal URL selection now derives the staging Hosting origin only when both the environment and Firebase project identify the allowlisted staging deployment, while production remains explicit and fail-closed. The original gate also recorded Community Guidelines V2 without presenting that policy; the gate and acknowledgement wording now represent Terms, Privacy, and Community Guidelines together. These client corrections were validated with a rebuilt device-test app and required no additional Hosting or Functions deployment.
