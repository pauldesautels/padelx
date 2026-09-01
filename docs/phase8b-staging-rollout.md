# Phase 8B staging rollout runbook

No staging project is configured in this repository. The only checked-in app
configuration targets `padelx-f168f`. Treat that project as production for this
procedure. Do not add a Firebase CLI default alias: every migration and deploy
must name its literal project ID.

## Command classification

The following commands are safe and local; they do not access remote Firebase
data:

```sh
flutter analyze
flutter test
npm run test:migration
npm run test:rules
git diff --check
```

Every command below that uses `firebase`, `flutterfire`, `gcloud`, or the
migration utility with a real project ID is a remote or deployment operation.
Run it only during an approved staging change window. Set the shell variable
manually and verify it before each group of commands:

```sh
export PADELX_STAGING_PROJECT_ID='your-literal-staging-project-id'
test "$PADELX_STAGING_PROJECT_ID" != 'padelx-f168f'
printf '%s\n' "$PADELX_STAGING_PROJECT_ID"
```

Never set `PADELX_STAGING_PROJECT_ID` to `padelx-f168f`.

## A. Create and configure staging

1. In Firebase Console, create a new project with a visibly non-production ID.
2. Record the immutable project ID as `PADELX_STAGING_PROJECT_ID` and verify the
   guard above.
3. Do not create `.firebaserc` or select a CLI default. Confirm CLI visibility:

   ```sh
   firebase projects:list
   firebase use
   ```

   `firebase use` should report that no active project is selected.

## B. Register staging apps

Register the platforms that will actually be smoke-tested (web first; Android
and iOS if beta binaries are in scope). Keep the existing bundle/package IDs if
staging is intended to exercise the same app identity. Obtain each app's
configuration from Firebase Console. Copy `config/staging.example.json` to
`config/staging.local.json` and enter the staging web app values. The local file
is ignored by Git.

Run the web app explicitly against staging:

```sh
flutter run -d chrome --dart-define-from-file=config/staging.local.json
```

For native builds, use a staging-local define file containing that platform's
app ID. Do not overwrite the checked-in production `google-services.json` or
`GoogleService-Info.plist` merely to test staging.

## C. Prepare Authentication and Firestore

In the staging Firebase Console:

1. Enable the same sign-in provider used by PadelX (email/password).
2. Create the Firestore database in the intended region.
3. Create dedicated, non-production Auth users for organizer, requester,
   second player, legacy owner, and attacker roles. Use disposable addresses.
4. Export or record the test UIDs. Do not copy production credentials or user
   passwords.
5. Before deploying Phase 8A rules, use temporary staging-only bootstrap rules
   only for controlled data seeding, then close access. Never reuse permissive
   bootstrap rules in production.

## D. Seed representative staging data

Use the Firebase Console or a reviewed, staging-only Admin script with the
literal project ID. Take an export immediately after seeding. Include:

- modern `users/{uid}` documents with the exact private schema and matching
  Auth emails, plus exact three-field `publicProfiles/{uid}` documents;
- a modern match with `creatorUid` and UID-only player snapshots;
- a legacy match owned only by `createdBy` UID;
- an email-only match owned by `creatorEmail` or `createdByEmail`, whose email
  maps to exactly one staging Auth user;
- pending, approved, and declined join requests;
- unread/read join-request and review notifications;
- a completed match with organizer and players;
- rating documents for completed-match participants;
- negative fixtures in a separate documented set: mismatched Auth email,
  unknown owner UID/email, conflicting legacy ownership fields, unexpected
  private/public fields, and a public profile differing from its private user.

Keep negative fixtures for the dry run only; they must produce blockers. Remove
or repair them before apply. Do not seed real production personal data.

## E–F. Dry run and resolve blockers

Authenticate Application Default Credentials with an account limited to the
staging project, verify the project guard, then run:

```sh
gcloud auth application-default login
node tool/migrate_phase8a.mjs --project="$PADELX_STAGING_PROJECT_ID"
```

The output must say `DRY RUN`, print the exact staging project ID, and end with
`No writes performed`. Exit code 2 or any `BLOCKER` is a stop. Resolve each
document manually, rerun, and retain the final zero-blocker output as evidence.

## G–H. Apply and verify

Create a Firestore managed export before apply. Then, with the guard rechecked:

```sh
node tool/migrate_phase8a.mjs --project="$PADELX_STAGING_PROJECT_ID" --apply
node tool/migrate_phase8a.mjs --project="$PADELX_STAGING_PROJECT_ID"
```

The second command is the post-apply dry run and should queue zero writes. In
Console or a read-only verification script confirm document counts and inspect
every seeded fixture: public profiles have exactly `uid`, `displayName`, and
`level`; match owner UIDs are correct; and no match creator/player email fields
remain. Preserve the export ID and outputs.

## I. Deploy rules and indexes to staging

Only after migration verification, preview the intended files locally and run:

```sh
firebase deploy --project="$PADELX_STAGING_PROJECT_ID" --only firestore:rules
firebase deploy --project="$PADELX_STAGING_PROJECT_ID" --only firestore:indexes
```

Deploying indexes is separate so its effects and errors are explicit. Never run
an unqualified `firebase deploy`.

## J. Authenticated smoke tests

Run the app with `config/staging.local.json` and real staging Auth sessions.
Capture pass/fail evidence for: profile create/edit atomicity; cross-user
private-profile denial; public-profile field allowlist; match creation; modern
and legacy-UID organizer actions; denial of email-only organizer authorization;
join request, approval, decline/retry, and leave; notification create/read;
completed-match immutability; valid ratings; duplicate/self-rating denial; and
representative malformed or malicious writes.

## K. Rollback and recovery

If dry run blocks, make no writes: repair or delete only the documented staging
fixtures and rerun. If apply fails, do not deploy rules. Earlier 400-write
batches may have committed; rerun the dry run. The migration is designed to be
idempotent: exact profiles are left untouched, field deletions are repeatable,
and missing profiles are created without overwrite. Resolve blockers and rerun
apply, or restore the pre-apply managed export into a fresh staging project.

If rules smoke tests fail, redeploy the previously recorded rules revision to
the literal staging project. Keep the migrated data unless the failure analysis
requires restoration; then restore the pre-apply export into a fresh project.
Firestore exports are not an in-place transactional rollback, so never rely on
them as a substitute for dry-run evidence and fixture-level verification.

## Production readiness gate

Do not repeat against `padelx-f168f` until staging provides retained evidence of
all of the following:

- zero migration blockers, a successful apply, and a zero-write post-apply dry
  run; all old data migrated or explicitly classified as incompatible;
- no cross-user read of `/users`, and only intentional three-field public
  profiles;
- no creator/player emails in matches and no organizer authorization from an
  email-only record, while modern `creatorUid` and legacy `createdBy` UID work;
- atomic profile create/edit and successful match creation;
- successful join request, approval/decline/retry, leave, notifications,
  completed-match behavior, and ratings;
- denial evidence for malformed fields, ownership spoofing, self/duplicate
  ratings, unauthorized notification updates, and other malicious writes;
- an identified production backup/export, change window, operator, rollback
  owner, exact production document counts, and reviewed command transcript;
- explicit approval to use the literal production project ID. The production
  dry run must occur first and its output must be reviewed before a separate
  approval for `--apply` or rules deployment.
