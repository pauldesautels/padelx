# Phase 8C closed-beta enrollment

## Architecture

Closed beta uses Firebase Authentication's project-level **disable user sign-up**
setting as the security boundary. That setting rejects account creation in every
client, including a modified app or direct Identity Toolkit request, while
continuing to allow existing Auth users to sign in.

An operator authorizes one tester by creating a passwordless Firebase Auth user
with the guarded Admin SDK utility in this repository. No invite list or email is
stored in Firestore. The invited tester then uses **Forgot password?** in PadelX.
Only the owner of the enrolled mailbox can receive the reset link, set the first
password, log in, and create the existing atomic `users/{uid}` plus
`publicProfiles/{uid}` profile pair.

Firestore rules are unchanged: private profiles remain owner-only and public
profiles retain their three-field schema. Auth account creation is not a
Firestore operation, so Firestore rules cannot enforce this gate.

## One-time staging rollout (do not run against production)

These are rollout instructions only. Phase 8C implementation does not execute
them.

1. In the Firebase console, open the literal project `padelx-staging`. Confirm
   the project ID in the project selector before changing anything.
2. Open Authentication settings and disable end-user account creation
   (the **User actions** setting). Leave the separate account-deletion choice at
   its existing value. If Firebase requires upgrading Authentication
   with Identity Platform to expose this setting, perform that upgrade for
   staging and review billing/quotas first. Keep Email/Password sign-in enabled.
3. Verify an existing staging user can still log in.
4. Verify a never-used email receives the app's neutral invite-only signup error
   and no Auth user is created.

Never make this console change in `padelx-f168f` without a separately reviewed
production change plan and explicit approval.

## Enroll one staging tester

Use credentials restricted to `padelx-staging`. First run the read-only preview:

```sh
gcloud auth application-default login
node tool/enroll_beta_tester.mjs \
  --project=padelx-staging \
  --confirm-project=padelx-staging \
  --email=tester@example.com
```

Check that the output says `DRY RUN`, `project=padelx-staging`, the intended
canonical email, and `status=create`. Then explicitly apply:

```sh
node tool/enroll_beta_tester.mjs \
  --project=padelx-staging \
  --confirm-project=padelx-staging \
  --email=tester@example.com \
  --apply
```

The utility refuses `padelx-f168f`, requires the project ID twice, creates no
password, writes no Firestore data, and is idempotent for an already enrolled
address. Do not share command output containing email addresses outside the
approved operator record.

Tell the tester to open PadelX, tap **Forgot password?**, enter the exact invited
email, use the link delivered to that mailbox to set a password, and then log in.
On first login the existing profile editor creates their private and public
profile documents.

## Remove an invitation

Before the tester finishes enrollment, disable or delete that passwordless Auth
user in the `padelx-staging` Firebase console. Resolve the exact email and UID
first. Deleting an established tester account can orphan application data and is
not part of this enrollment utility.

## Local verification

```sh
flutter analyze
flutter test
npm run test:beta
npm run test:rules
npm run test:migration
git diff --check
```

## Limitations and operations

- Firebase administrators and service accounts with Auth write permission can
  still create users; restrict and audit that IAM access.
- Mailbox security and Firebase password-reset security are the proof of invite
  ownership. A compromised mailbox can complete enrollment.
- The console setting is environment-specific configuration and is not captured
  by Firestore rules or `firebase.json`; verify it explicitly after cloning or
  recreating an environment.
- Password reset requests should use Firebase email-enumeration protection. The
  app intentionally shows the same sent/closed-beta guidance rather than an
  invite lookup.
