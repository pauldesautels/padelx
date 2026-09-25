# Android release signing

PadelX uses the standard Google Play signing model:

- Google Play holds the app-signing key used for distributed APKs.
- The developer holds a separate PadelX upload key used to sign uploaded AABs.

The permanent production package is `com.pabloware.padelx`. The upload key must
not be reused by another app, and the Android debug key must never sign a store
artifact.

## Local custody

Store the keystore outside the repository in a user-private directory, for
example:

`~/Library/Application Support/PadelX/signing/padelx-upload.jks`

Copy `android/key.properties.example` to the ignored
`android/key.properties`, replace `storeFile` with the absolute local path,
and enter the passwords locally. Never commit that file or the keystore.

Production release tasks fail closed when the properties file, any required
property, or the configured keystore is missing. Debug and staging-debug builds
continue to use Android's normal debug signing path.

## Secret creation and backup

Generate the key interactively so passwords never appear in shell history,
source files, chat, or logs. Back up the following in two secure locations:

- the upload keystore;
- its alias;
- the keystore and key passwords in a password manager;
- a certificate export and SHA-256 fingerprint metadata.

The exported certificate and fingerprint identify the developer-held upload
key. They are distinct from Google Play's app-signing certificate and
fingerprint, which identify the key Play uses for distributed app packages.

An upload-key reset through Google Play is an emergency recovery option, not a
replacement for backups. Never attempt to export Google's app-signing private
key.

## Production build boundary

A real build uses an ignored `config/production.local.json` populated from
approved production provider values:

```text
flutter build appbundle --release --flavor production \
  --dart-define-from-file=config/production.local.json
```

Do not build a release from `config/production.example.json`; it intentionally
contains placeholders. Before upload, verify the AAB package, version code,
Firebase project, signing certificate, and that Play Integrity/App Check setup
matches the final Play application.

Production native release builds select the attested App Check provider
automatically. Android therefore compiles with the Play Integrity provider but
is not runtime-ready until the Play/Firebase App Check registration is
completed. Production native debug/profile builds do not receive a debug
fallback.

Every later Play upload must use a version code greater than the previously
uploaded bundle.
