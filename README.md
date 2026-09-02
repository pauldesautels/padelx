# PadelX

A Flutter application for PadelX.

## Firebase environment safety

PadelX has no implicit Firebase environment. Every run and build must explicitly
select `development`, `staging`, or `production` and provide the Firebase project
ID, API key, app ID, and messaging sender ID. A plain `flutter run` fails before
Firebase initializes.

Non-production environments are prohibited from targeting the production project
`padelx-f168f`. Conversely, that project can only be selected by an explicit
`FIREBASE_ENVIRONMENT=production` configuration. Configuration errors report
field names only and never print configuration values. Debug builds cannot
target production even when given an explicit production configuration.

Local configuration files use the `config/*.local.json` naming convention and
are ignored by Git. Never commit one of these files.

## Firebase App Check

For the staging web environment only, App Check is activated after Firebase
initialization and before the widget tree can access Firebase Auth or Firestore.
Provider selection is explicit through `FIREBASE_APP_CHECK_MODE`: `debug` uses
the Firebase debug provider for localhost, while `attested` uses reCAPTCHA
Enterprise and requires `FIREBASE_APP_CHECK_RECAPTCHA_ENTERPRISE_SITE_KEY`.
The integration verifies that the project ID is exactly `padelx-staging`.

Development, non-web, and production configurations do not activate App Check
through this staging-only integration. It does not enable remote enforcement or
alter the Google Places REST integration.

## Local web development

Copy the safe template, then replace every Firebase placeholder with values for
a non-production Firebase web app. Add a development Google Places key if the
Places features are needed.

```sh
cp config/development.example.json config/development.local.json
flutter run -d chrome --dart-define-from-file=config/development.local.json
```

Local development may use the staging Firebase app when a separate development
project is unavailable, but the file must retain
`FIREBASE_ENVIRONMENT=development` and must never contain `padelx-f168f`.

## Staging web

Copy the staging template and fill it with the web-app values from the literal
Firebase project `padelx-staging`. For localhost, explicitly change
`FIREBASE_APP_CHECK_MODE` to `debug`; the Enterprise key is then neither used nor
required.

```sh
cp config/staging.example.json config/staging.local.json
flutter run -d chrome --dart-define-from-file=config/staging.local.json
```

For hosted staging, explicitly use `attested` and provide the registered
Enterprise site key. The checked-in example placeholders deliberately fail
attested validation. Never commit debug tokens, and do not add localhost to the
Enterprise domain allowlist.

## Eventual production build

Production also requires a complete ignored configuration file and explicit
environment selection. Prepare it from the template, review every value, and use
it only for an intentional production build:

```sh
cp config/production.example.json config/production.local.json
flutter build web --release --dart-define-from-file=config/production.local.json
```

This command is documentation only; production builds and deployments are not
part of ordinary local or staging development.

## Firebase operations

Firebase CLI deployments and the Phase 8A migration intentionally have no
repository default or alias. Always pass the literal target project ID with
`--project`; see `docs/phase8b-staging-rollout.md` before any remote operation.
