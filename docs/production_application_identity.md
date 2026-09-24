# Production application identity

PadelX reserves `com.padelx.app` as the permanent production identity for
both the Apple App Store bundle ID and the Google Play application ID. The
visible application name remains **PadelX**.

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

Provider-generated production files must be replaced only after native apps
with `com.padelx.app` have been registered in the production Firebase project.
Until then, production builds are expected to reject the existing mismatched
Firebase configuration. Never substitute staging configuration to make a
production build pass.

The later external setup order is:

1. Register the production Android Firebase app for `com.padelx.app`, then
   obtain its `google-services.json`.
2. Create the Google Play application for the same permanent application ID;
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
