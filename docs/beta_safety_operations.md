# PadelX beta safety operations

## Public contact

The monitored beta inbox is **support.padelx@gmail.com**. It handles general
support, safety and abuse concerns, appeals, and privacy or account requests.
The address is public and is not a secret.

A named safety owner and backup must be assigned operationally before beta.

## Review workflow

- Review open reports daily during the closed beta.
- Prioritize threats and unsafe-behavior reports.
- A report count alone never triggers enforcement.
- PadelX reporting and support are not emergency services. Direct immediate
  danger to local emergency services.
- Beta moderation remains manual. Safety Phase 4B provides internal enforcement
  services and access controls only; privileged operator tooling remains Phase 4C.

## Account enforcement operations

- Normal suspension and ban state is stored in the server-only
  `accountEnforcement` collection. It must not disable the Firebase Auth user.
- Refresh tokens are revoked after enforcement is applied or revoked to shorten
  the lifetime of an existing session. Firestore rules and callable admission
  remain the authoritative boundary.
- An expired suspension stops restricting access based on authoritative time even
  if cleanup has not run. Recording `suspension_expired` and removing stale active
  records remains a future reconciliation task; Firestore TTL must not be enabled.
- A future match involving an enforced organizer can require manual Phase 4C
  remediation. Enforcement does not automatically cancel or rewrite matches.
- Emergency Firebase Auth disable is a separate exceptional operator action for
  an immediate incident response, not a normal suspension or ban. It requires an
  explicitly authorized operator, an incident record, and a recovery plan; it
  must not be automated from reports, ratings, blocks, or report counts.

## Internal privacy

- Use individual authorized accounts; do not share administrator credentials.
- Do not export reports to personal devices.
- Do not copy sensitive report or message evidence into general chat or email.
- Access report evidence only when needed for review.

## Approved retention targets

- Retain unresolved `open` or future `reviewing` reports until resolution.
- Target 12 months after resolution for resolved report evidence.
- Target 24 months after resolution for minimal pseudonymized moderation and
  audit metadata.
- A future approved legal or safety hold may suspend deletion.

These targets are **not technically enforced yet**. Report resolution, evidence
and metadata separation, legal holds, and report TTL/deletion remain future work.
Reports continue to survive account deletion under the existing behavior.

`reportRateLimits.expiresAt` prepares operational rate-limit records for future
TTL cleanup. Runtime checks remain authoritative. Do not enable TTL until the
permanent duplicate protection for message reports is represented outside the
expiring rate-limit record.
