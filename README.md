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
