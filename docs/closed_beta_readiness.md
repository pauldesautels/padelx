# Closed beta readiness and final-launch checklist

This document separates repository-complete beta work from configuration that
must be performed by a human in the correct Firebase, Apple, or Google account.
It does not certify production, replace legal advice, or authorize deployment.

## Code complete locally

- The client fails closed when its Firebase environment or native app identity
  is missing or inconsistent. Debug and device-test builds cannot target the
  production project implicitly.
- Push registration is Auth-, App Check-, project-, and application-bound.
  Device records are server-only and support multiple devices, token refresh,
  locale refresh, sign-out/account-switch cleanup, invalid-token cleanup, and
  account deletion.
- One server delivery seam handles the time-sensitive Quick Match offer,
  partner invitation, AutoFill replacement offer, and confirmed-match events.
  Delivery is preference-aware, localized to English or es-MX, bounded to 20
  recipient devices, retry-claimed by a deterministic receipt, and uses
  privacy-safe generic copy and allowlisted routes.
- Release-native Crashlytics capture is disabled in debug and on web. It records
  fatal Flutter/platform failures and explicitly approved sanitized nonfatals.
  Metadata is limited to environment and build number, and monitoring failure
  cannot block startup.
- Account deletion removes push devices, notification preferences,
  notifications, and delivery receipts owned by the deleting account.

## Push privacy and operational model

Push payloads must never contain private venue addresses or coordinates,
messages, report evidence, enforcement state, raw Reliability events, emails,
UIDs, tokens, or proposal identifiers. A confirmed-match notification may carry
only the canonical match identifier needed to retrieve authorized current state.
Other supported events route to the current Quick Match state.

Provider delivery is inherently external. The deterministic receipt prevents
concurrent/retried triggers from intentionally sending the same notification
again; Android and APNs collapse identifiers further bound duplicate display.
Receipts persist only delivery status and aggregate counts, never provider
errors or device tokens.

## Legal product-accuracy review package

The accepted legal versions remain `terms-beta-v1`, `privacy-beta-v1`, and
`community-beta-v1`. Do not change the following text or versions until a human
legal/product review approves the complete English and es-MX wording.

Outdated product descriptions:

1. `web/terms/index.html` says PadelX does not provide automatic matchmaking.
2. `web/es-MX/terms/index.html` says PadelX does not provide automatic
   matchmaking.
3. `web/community-guidelines/index.html` says no Reliability feature exists.
4. `web/es-MX/community-guidelines/index.html` says no Reliability feature
   exists.
5. The in-app Community Guidelines in `lib/safety_policy.dart` and the
   `guidelineReliabilityTitle`/`guidelineReliabilityBody` ARB strings describe
   Reliability only as a future possibility.

Proposed factual English language for review, not pre-approved legal copy:

- Terms product list: “PadelX currently supports profiles, player and match
  discovery, Quick Match matchmaking, matches, requests, social connections,
  messages, ratings, notifications, Reliability, reports, moderation and
  deletion. It does not currently provide payments.”
- Guidelines: “PadelX may use objective participation events, such as confirmed
  match cancellations, to present a Reliability percentage after sufficient
  history. Reliability is not a safety score, does not infer no-shows
  automatically, and does not cause automatic enforcement.”

Proposed factual es-MX language for review, not pre-approved legal copy:

- Terms product list: “PadelX admite perfiles, búsqueda de jugadores y
  partidos, emparejamiento Quick Match, partidos, solicitudes, conexiones
  sociales, mensajes, calificaciones, notificaciones, Confiabilidad, reportes,
  moderación y eliminación. Actualmente no ofrece pagos.”
- Guidelines: “PadelX puede usar eventos objetivos de participación, como la
  cancelación de un partido confirmado, para mostrar un porcentaje de
  Confiabilidad después de contar con historial suficiente. La Confiabilidad no
  es una calificación de seguridad, no infiere ausencias automáticamente ni
  genera medidas automáticas.”

Review must decide whether correcting these descriptions is material enough to
issue new legal versions and require acknowledgement again.

## Small-beta operating procedure

Assign roles before inviting users:

- **Primary beta operator:** monitors support, reports, deletion jobs, Functions
  failures, and release crashes each beta day.
- **Backup beta operator:** has tested access to the same runbooks and takes over
  when the primary is unavailable.

Never place report evidence, private locations, message bodies, tokens, or
credentials in tickets, chat, screenshots, or ad-hoc logs.

Daily procedure:

1. Review `support.padelx@gmail.com` for support, safety, privacy, appeals, and
   deletion requests.
2. Use the existing staging-tested safety-admin CLI to list open reports, claim
   review, view sensitive evidence only with explicit confirmation, and link any
   separately justified enforcement action.
3. Prioritize credible immediate threats or unsafe real-world behavior. Remind
   users that PadelX is not an emergency service.
4. Do not enforce from report count or reason alone. Record the reviewed action
   through existing moderation services.
5. Inspect blocked or retrying deletion jobs and use the existing idempotent
   recovery path. Never manually delete a partial subset of account data.
6. Review Quick Match recovery and push-delivery errors using sanitized IDs and
   status codes only.

## Incident runbook

### Push delivery failure

Check trigger error rate, receipt status, recipient preferences, device count,
provider status, and invalid-token cleanup. Do not print tokens. If delivery is
degraded, keep in-app notifications authoritative and tell beta users that
time-sensitive offers may require the app to remain open.

### Quick Match recovery failure

Inspect the scheduled recovery Function, bounded batch result, request/proposal
states, required indexes, and lock consistency. Do not directly edit a proposal,
active-owner lock, or canonical match. Prefer the idempotent recovery operation.

### Account deletion recovery failure

Inspect the job phase, checkpoint, lease, safe error code, scheduler/IAM state,
and deletion barrier. Retry through the existing recovery Function. Escalate any
ambiguous state; never remove the barrier merely to restore access.

### Elevated Function errors

Confirm project/environment first, then group by Function and safe error code.
Check provider incidents, indexes, quotas, App Check, and recent releases. Do not
copy request payloads containing private data into an incident record.

### Crashlytics crash

Confirm environment and build number, reproduce without personal data, and
verify symbols before diagnosis. Critical authentication, deletion, messaging,
matchmaking, and private-location crashes take priority.

### Private-location concern

Treat as a high-priority privacy incident. Preserve authorized evidence, verify
that no push/log/public projection exposed address or coordinates, restrict an
account only through the enforcement service when justified, and communicate
through the support inbox.

### Abuse or safety report

Follow the review procedure above. For immediate danger, direct the reporter to
local emergency services. PadelX support is not an emergency service.

### Firebase outage or degradation

Check official provider status, pause invitations to time-sensitive Quick Match
flows, avoid manual data repair, communicate the affected capability, and test
recovery in staging before resuming beta activity.

## Abuse and rate-limit review

- Push registration is authenticated, App Check protected, app-identity bound,
  idempotent by token hash, and limited to the caller’s account. Delivery fanout
  is capped at 20 devices.
- Quick Match and partner operations use server admission, bounded scans,
  deterministic request identities, active-owner locks, short expirations, and
  transactional revalidation.
- Messaging has bounded text/page sizes, request-id idempotency, membership
  authorization, and a server rate window.
- Reports use deterministic request IDs, duplicate protection, a 24-hour rolling
  reporter policy, and target cooldowns.
- Friend and join-request operations are authorization- and state-transition
  constrained. Their operational volume should be monitored during beta; no
  additional persistent limiter is justified before evidence of abuse.
- Account deletion uses reauthentication/admission, a durable barrier,
  idempotent phases, bounded batches, and scheduled recovery.
- Signup and password abuse remain primarily Firebase Auth/provider controls and
  must be reviewed in the Firebase Console before launch.

## Version compatibility

A minimum-version or maintenance-mode service is not required for the current
additive closed-beta code. It becomes P0 before deploying any backend, rules, or
schema change that an already distributed client cannot use safely. At that
point, design the smallest fail-closed availability check before releasing the
breaking backend change; do not rely on store adoption speed.

## Backup and recovery assumptions

Canonical data includes Auth identities, private/public profiles, canonical
matches, conversations/messages, friendships/blocks, matchmaking requests and
proposals, reports/evidence, moderation/enforcement records, objective
Reliability events, legal/eligibility records, and deletion jobs.

Some projections can be rebuilt from canonical sources, including player/match
views, conversation views, rating aggregates, played-with history, location
indexes, and Reliability profiles. Provider tokens, Auth credentials, deleted
content, expired external logs, and evidence removed under an approved retention
policy cannot be reconstructed from projections.

Before a broader public launch, decide whether to enable managed Firestore
backup/PITR, document its cost and retention, test a restoration into an isolated
project, and define who can authorize recovery. Do not treat provider backup as
an alternative to account deletion or approved retention rules.

## Privacy-conscious beta metrics

Use aggregate counts/durations; do not create player-level performance or safety
dashboards.

Already derivable from server state/events:

- Quick Match searches and time from request to first offer;
- offer acceptance and lobby completion;
- time to four confirmed players;
- venue completion and canonical matchmaking-created matches;
- confirmed-match cancellations and categorized lead time;
- AutoFill activation, success, and replacement duration;
- aggregate Reliability status/percentage distribution;
- Create Match count from canonical match source.

Not currently derivable without explicit analytics instrumentation:

- views or taps in Find Matches;
- abandoned Create Match forms;
- impressions of explanations or warnings.

Do not add an analytics SDK solely for the closed beta. If learning needs later
justify instrumentation, define a reviewed allowlist with aggregate purpose,
retention, consent/disclosure implications, and no private location or message
content.

## Retention review

- Notifications have a documented 90-day target but no automated cleanup.
- Push devices remain until opt-out, invalidation, sign-out/account switch, or
  account deletion.
- Push delivery receipts currently remain until account deletion; operations and
  legal review must approve a bounded cleanup period before automation.
- Matchmaking requests/proposals use operational expirations and recovery, but
  historical retention has no separate approved deletion schedule.
- Objective Reliability events and their projection are removed for account
  deletion; broader retention remains an unresolved policy decision.
- Open/reviewing reports remain through resolution. Resolved evidence has a
  documented 12-month target and minimal audit metadata a 24-month target; these
  targets are not technically enforced.
- Account deletion follows the documented staged deletion and preservation
  policy, including necessary anonymized or safety/audit records.

TTL remains disabled. Do not enable it until permanent message-report
deduplication is separated from cleanup-oriented rate-limit state and legal/
operations approve each collection’s policy.

## Firebase Auth final-launch checklist

1. Review enabled providers and authorized domains in the selected project.
2. Review English and es-MX verification and password-reset templates; client
   language selection alone does not localize Console templates automatically.
3. Verify sender name/address and reply/support expectations.
4. Verify action URLs and continue/deep-link destinations for both locales.
5. Test new, expired, malformed, and already-used verification/reset links on a
   physical device and browser.
6. Test spam placement with representative providers without recording test
   credentials in the repository.
7. Confirm failures remain sanitized and do not reveal whether unrelated
   accounts exist.

## Apple final-launch phase (deferred)

1. Enroll/pay for the Apple Developer Program.
2. Select the enrolled team and final App ID/bundle identity.
3. Configure signing and provisioning.
4. Enable Push Notifications and required remote-notification background mode.
5. Create the APNs key externally and upload it to the correct Firebase app.
6. Register the release App Check provider.
7. Configure Crashlytics dSYM upload and verify symbolication.
8. Create App Store Connect/TestFlight records and builds.
9. Complete privacy disclosures, support/privacy/account-deletion URLs, age
   rating, screenshots, metadata, and review notes.
10. Physically validate foreground/background/terminated push, tap routing,
    opt-out, token refresh, account switch, and deletion cleanup.
11. Submit only after legal approval and staging release validation.

Do not put an APNs key, signing credential, team-specific secret, or local
release configuration in the repository.

## Android final-launch phase (deferred)

1. Create/pay for the Google Play developer account.
2. Establish release signing and secure key custody.
3. Create the final Play application and production Firebase Android app.
4. Configure FCM and release App Check.
5. Configure Crashlytics mapping-file upload and verify a symbolicated release
   failure.
6. Run internal testing followed by an appropriately limited release test.
7. Complete Data Safety, account-deletion, support/privacy URLs, screenshots,
   metadata, content rating, and review declarations.
8. Physically validate notification channels, foreground/background/terminated
   behavior, tap routing, opt-out, token refresh, account switching, and cleanup.
9. Submit only after parity, legal, security, and release checks pass.

No Apple/Google enrollment, store application, credential creation, build
upload, or review submission is part of Beta Readiness Phase 1.
