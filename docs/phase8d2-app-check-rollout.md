# Phase 8D.2 staging web App Check

The client activates App Check only when all of these conditions are true:

- `FIREBASE_ENVIRONMENT` is `staging`;
- `FIREBASE_PROJECT_ID` is exactly `padelx-staging`; and
- the app is running on web.

Activation occurs immediately after `Firebase.initializeApp` and before
`runApp`, Firebase Auth, or Firestore access. The provider is selected only by
`FIREBASE_APP_CHECK_MODE`, never by Flutter's debug/release mode:

- `debug` uses the Firebase App Check web debug provider and does not read or
  require the Enterprise site key.
- `attested` uses reCAPTCHA Enterprise and requires its registered public site
  key.

Production rejects `debug`. Development without a staging App Check mode keeps
its existing behavior. Native staging combinations fail closed because this
rollout supports web only.

For localhost, the ignored staging configuration must select:

```json
"FIREBASE_APP_CHECK_MODE": "debug"
```

The Firebase web SDK generates the debug token. Register it only in the
`padelx-staging` App Check debug-token list; do not put it in any config or
tracked file.

For hosted staging, select `attested` and provide the registered public site key:

```json
"FIREBASE_APP_CHECK_MODE": "attested",
"FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY": "your-registered-site-key"
```

Do not add secrets or private credentials to tracked configuration. No Firebase
enforcement setting is changed by the client SDK.

## Manual staging steps

1. Copy `config/staging.example.json` to the ignored
   `config/staging.local.json` if it does not already exist.
2. Keep `FIREBASE_PROJECT_ID` set to `padelx-staging` and select `debug` for
   localhost testing. The Enterprise key may remain absent or placeholder in
   this mode.
3. Run web with
   `--dart-define-from-file=config/staging.local.json`.
4. Register the generated debug token only in `padelx-staging`. Do not add
   localhost to the Enterprise domain allowlist.
5. For a later hosted staging build, switch explicitly to `attested`, supply the
   registered site key, and use only the authorized staging domains.
6. Verify App Check metrics in the `padelx-staging` Firebase Console before any
   separately authorized enforcement decision. Leave enforcement disabled.

Do not perform these steps in `padelx-f168f`.
