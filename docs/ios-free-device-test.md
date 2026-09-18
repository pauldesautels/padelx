# Free Apple Personal Team device test

This path is intentionally limited to a debug build on Paul's iPhone. It does
not replace the `staging` scheme or its App Attest and DeviceCheck fallback.

## Firebase setup

In the existing `padelx-staging` Firebase project, register an Apple app with
bundle ID `com.padelx.app.devicetest`. Downloading or adding its
`GoogleService-Info.plist` is not required for this configuration: Flutter
initializes Firebase from explicit Dart options, and the Xcode build phase
removes any bundled Firebase plist from `Debug-device-test`.

Copy `config/device-test.ios.example.json` to
`config/device-test.ios.local.json` and fill it only with values shown for that
new staging Apple app. Do not use values from `padelx-f168f`.

`LEGAL_BASE_URL` should remain `https://padelx-staging.web.app`. The client also
derives that URL only when both the selected environment and project are the
allowlisted staging values. Production has no implicit legal-site fallback and
must be configured explicitly.

`GOOGLE_PLACES_API_KEY` must be a dedicated staging-native iOS key, not the
web-staging key. In Google Cloud, restrict it to **iOS apps**, allow only bundle
ID `com.padelx.app.devicetest`, and restrict its API access to **Places API
(New)**. Native autocomplete and Place Details requests send the configured
bundle ID in `X-Ios-Bundle-Identifier`; web requests do not send that header.

In Firebase Console, open App Check for the new Apple app (register the app in
App Check if the console asks), run the debug build once to obtain its debug
token, and use the app's overflow menu to manage and register that token. App
Check enforcement on staging services remains in place; only registered debug
tokens for this staging app are accepted.

## Xcode signing

Open `ios/Runner.xcworkspace`, select the `Runner` target and the
`Debug-device-test` configuration, enable automatic signing, and select Paul's
Personal Team. The configuration has no App Attest entitlement because a free
Personal Team cannot provision that capability. The normal staging
configurations continue using `Runner.entitlements`.

Run only with the `device-test` scheme and explicit compile-time file:

```sh
flutter run --flavor device-test \
  --dart-define-from-file=config/device-test.ios.local.json \
  -d 00008140-001A1D800E46801C
```

The application fails before Firebase initialization if the environment is not
`staging`, the project is not `padelx-staging`, the native Apple App ID or
device-test bundle ID is wrong, the device-test flag is absent, or the build is
not debug.
