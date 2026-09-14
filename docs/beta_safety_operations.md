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
- Beta moderation remains manual. Suspension and enforcement architecture is
  deferred to Safety Phase 4B.

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
