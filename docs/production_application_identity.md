# Production application identity

PadelX uses separate permanent production identities by platform:

- Android production: `com.pabloware.padelx`
- iOS production: `com.padelx.app`

Google Play reported `com.padelx.app` unavailable. Before Play app creation,
`com.pabloware.padelx` was explicitly checked and reported available, so it is
the permanent Android production identity. The visible application name
remains **PadelX**.

Native store identities are effectively permanent once an application is
distributed. Changing either identifier later would create a different app
rather than an ordinary update, so these production values must not be changed
casually.

Non-production identities remain deliberately separate:

- iOS staging: `com.padelx.app.staging`
- iOS device test: `com.padelx.app.devicetest`
- Android staging: `com.example.padelx`

The Android Kotlin namespace and source package remain
`com.example.padelx`; they are implementation namespaces and do not determine
the production Play application ID.

## Fail-closed configuration boundary

The production Firebase project retains historical Android registrations for
`com.example.padelx` and `com.padelx.app`; they must not be deleted as part of
this migration. The checked-in provider configuration does not yet contain an
Android client for `com.pabloware.padelx`, so production Android builds must
fail closed until that new app is registered and a fresh provider-generated
configuration is reviewed. Never manually edit provider configuration or
substitute staging configuration to make a production build pass.

The later external setup order is:

1. Register the production Android Firebase app for `com.pabloware.padelx`,
   then obtain its provider-generated `google-services.json`.
2. Create the Google Play application for the same Android application ID;
   configure release signing and Play Integrity in separately reviewed steps.
3. After Apple Developer membership is active, register the explicit App ID
   `com.padelx.app`.
4. Register the production iOS Firebase app for that bundle ID and obtain its
   `GoogleService-Info.plist`.
5. Configure Apple signing, required capabilities, APNs, and then the App
   Store Connect application in separately reviewed steps.

Firebase Auth callback schemes and native Firebase app IDs are
provider-generated and must be regenerated with the new production Firebase
apps. App Check production providers, push credentials, Crashlytics symbol
upload, store listings, and signing are intentionally outside this repository
preparation.
