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
- Beta moderation remains manual. The Phase 4C command-line tool is restricted
  to trusted beta administrators and **only supports `padelx-staging`**. It is
  not production-ready moderator architecture.

### Staging moderator procedure

1. Monitor the shared support inbox.
2. Run the urgent report queue, then the open queue, at least daily.
3. Start review to claim one exact report.
4. Inspect minimal metadata first. Display sensitive evidence only when it is
   necessary to decide that report.
5. Dismiss the report with `no_violation` or `insufficient_evidence`, or perform
   enforcement as a separate deliberate operation.
6. When enforcement is justified, suspend or ban the exact account with the
   report ID as a source. Then explicitly mark only that report `actioned` using
   the returned moderation action ID.
7. Release the review if it cannot be completed. There is no silent timeout,
   reassignment, or takeover.

Never act from report count alone. PadelX is not an emergency service; direct
immediate danger to local emergency services.

The committed CLI is `tool/safety_admin/index.mjs`. Every invocation requires
an explicit staging project and confirmation plus an exact actor UID. Mutations
are dry-run by default and require `--apply`, a stable UUID request ID, and exact
target confirmation where applicable. Use individual moderator accounts and
grant only the reviewer or enforcer claim needed for the person's duties.

The CLI uses Google Application Default Credentials for backend access and
reads current Firebase Auth custom claims for the supplied actor UID on every
invocation. The actor UID is **not cryptographically bound** to the Google ADC
principal. Only trusted beta administrators may run it. It hard-refuses the
production project `padelx-f168f`; do not adapt or use it for production.

Bootstrap the first combined beta administrator outside this CLI using an
explicitly approved Firebase Admin operation. Thereafter, a currently combined
reviewer/enforcer account may manage the two independent claims with `roles
show`, `roles grant`, and `roles revoke`. Role changes preserve unrelated custom
claims, verify the result, revoke refresh tokens, and append an audit event.

Typical command shapes are:

```text
node tool/safety_admin/index.mjs reports list-urgent --project=padelx-staging --confirm-project=padelx-staging --actor-uid=ACTOR_UID
node tool/safety_admin/index.mjs reports start-review REPORT_ID --project=padelx-staging --confirm-project=padelx-staging --actor-uid=ACTOR_UID --request-id=UUID --apply
node tool/safety_admin/index.mjs enforcement suspend TARGET_UID --project=padelx-staging --confirm-project=padelx-staging --actor-uid=ACTOR_UID --target-uid=TARGET_UID --confirm-target-uid=TARGET_UID --reason=other_policy_violation --minutes=60 --source-report-id=REPORT_ID --request-id=UUID --apply
node tool/safety_admin/index.mjs reports action REPORT_ID --project=padelx-staging --confirm-project=padelx-staging --actor-uid=ACTOR_UID --resolution-action-id=ACTION_ID --request-id=UUID --apply
```

Omit `--apply` for a dry run. Generate a UUID deliberately and reuse the same
value to retry the exact same mutation; the CLI never generates one silently.
Use `--source-report-id=REPORT_ID` for one linked report. The optional plural
form `--source-report-ids=ID_ONE,ID_TWO` supports a bounded set and removes
duplicates before the internal enforcement policy validates it. Omit both only
for legitimate off-platform enforcement that has no PadelX report source.

Do not export report evidence, redirect sensitive output, take screenshots, or
copy message text/details into notes, email, chat, or tickets. Moderator notes
must be concise and factual and must not contain copied evidence, diagnoses,
speculation presented as fact, unrelated personal data, credentials, tokens, or
other unnecessary private data. Raw evidence is limited to the single immutable
snapshot stored with the selected report; never fetch surrounding messages.

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
