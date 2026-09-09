# Native iOS staging Firebase configuration

After registering the iOS app `com.padelx.app.staging` in the Firebase project
`padelx-staging`, download its configuration file and place it here as:

`GoogleService-Info.plist`

The real plist is ignored by Git. The `staging` Xcode scheme fails its build if
the file is missing, if it belongs to another Firebase project or bundle ID, or
if its Firebase App ID is not a native iOS App ID. Never copy the production
plist into this directory.

Create `config/staging.ios.local.json` from
`config/staging.ios.example.json` and replace its example-only values with the
values for the same registered Firebase iOS app. The local file is also ignored
by Git.
