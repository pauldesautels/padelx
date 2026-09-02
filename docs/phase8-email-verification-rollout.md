# Phase 8 email verification rollout

PadelX now treats a verified Firebase Authentication email as the boundary for
all application Firestore access. Public email/password signup remains enabled.
After signup, the client sends Firebase's verification message and holds the
session on the verification screen. No profile document can be created until
the account's `email_verified` token claim is true.

The Continue action reloads the current Firebase user and, after verification,
forces an ID-token refresh before allowing profile setup. The Firestore rules
independently require `request.auth.token.email_verified == true`; the client
gate is user experience, not the security boundary.

## Staging validation

1. Deploy the updated rules and staging app only as a separately authorized
   rollout step. This repository change does not deploy them.
2. Confirm the staging Firebase Authentication email/password provider remains
   enabled and review the verification email template, sender name, authorized
   domains, continue URL, localization, and spam-folder behavior.
3. Create a new staging account and confirm no `users/{uid}` or
   `publicProfiles/{uid}` document exists before verification.
4. Confirm reads and writes receive permission denied before verification.
5. Open the verification link, return to PadelX, press **I've verified my
   email**, and confirm profile creation and normal application access work.
6. Exercise resend cooldown, expired links, sign out, sign back in, and the
   flow on each release platform.

## Existing accounts and production rollout

No account is silently marked verified. When these rules are eventually
deployed, every existing Firebase Auth account with `emailVerified == false`
will immediately lose application Firestore access and will be routed to the
verification screen. Existing profile and match data is not deleted.

Before any production rollout, an operator must inventory unverified Auth
accounts and explicitly choose a policy: require those users to verify normally,
contact them before enforcement, or—only with documented proof of mailbox
ownership—set verification administratively. Never bulk-mark accounts verified
merely because they predate this feature. Stage and rehearse the rules/app
ordering so older clients cannot leave users on an unexplained permission error.

Firebase verification delivery and per-address resend throttling remain
provider-controlled. The client cooldown improves user experience and prevents
accidental double submissions, but it is not a server-side abuse control.
