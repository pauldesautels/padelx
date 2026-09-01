# PadelX

A Flutter application for PadelX.

## Local web development

The app reads the Google Places API key at compile time using
`String.fromEnvironment('GOOGLE_PLACES_API_KEY')`. Keep development secrets in
`config/development.local.json`, which is ignored by Git.

1. Open `config/development.local.json` on your Mac and put your development
   Google Places API key between the empty quotes.
2. Launch the app from the project root:

   ```sh
   flutter run -d chrome --dart-define-from-file=config/development.local.json
   ```

`config/development.example.json` is a safe template that can be committed.
Additional environments can use separate files and keys, such as an ignored
`config/production.local.json`, selected with the same
`--dart-define-from-file` option during the relevant build or run.

## Firebase environments

The default development build keeps using the checked-in `padelx-f168f`
FlutterFire configuration. To run against another Firebase project, copy
`config/staging.example.json` to the ignored `config/staging.local.json`, fill
in that project's web or platform app values, and run:

```sh
flutter run -d chrome --dart-define-from-file=config/staging.local.json
```

When `FIREBASE_ENVIRONMENT` is not `development`, the app refuses to start
without an explicit `FIREBASE_PROJECT_ID`. When a project override is present,
its API key, app ID, and messaging sender ID are also mandatory, preventing a
partial staging/production configuration from silently mixing projects.

Firebase CLI deployments and the Phase 8A migration intentionally have no
repository default or alias. Always pass the literal target project ID with
`--project`; see `docs/phase8b-staging-rollout.md` before any remote operation.
