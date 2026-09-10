# Android staging Firebase configuration

Register the existing Android application ID `com.example.padelx` in the
Firebase project `padelx-staging`, then place its downloaded configuration at:

`android/app/src/staging/google-services.json`

The real file is ignored by Git. Staging Google Services tasks fail before
processing if it is missing, targets another project, or contains another
package identity. Run staging builds with the `staging` flavor and a matching
staging-only Dart define file.
