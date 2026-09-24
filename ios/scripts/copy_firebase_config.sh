#!/bin/sh
set -eu

destination="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/GoogleService-Info.plist"

case "${CONFIGURATION}" in
  *-device-test)
    # Firebase is initialized from explicit Dart options for device-test builds.
    # Removing the destination prevents any production plist from
    # being selected implicitly by a native Firebase SDK.
    /bin/rm -f "${destination}"
    exit 0
    ;;
  *-staging)
    source_plist="${PROJECT_DIR}/Runner/Firebase/Staging/GoogleService-Info.plist"
    expected_project="padelx-staging"
    expected_bundle="com.padelx.app.staging"
    ;;
  *)
    source_plist="${PROJECT_DIR}/Runner/GoogleService-Info.plist"
    expected_project="padelx-f168f"
    expected_bundle="com.padelx.app"
    ;;
esac

if [ ! -f "${source_plist}" ]; then
  echo "error: Missing Firebase plist: ${source_plist}" >&2
  exit 1
fi

if [ -n "${expected_project}" ]; then
  actual_project=$(/usr/libexec/PlistBuddy -c 'Print :PROJECT_ID' "${source_plist}" 2>/dev/null || true)
  actual_bundle=$(/usr/libexec/PlistBuddy -c 'Print :BUNDLE_ID' "${source_plist}" 2>/dev/null || true)
  google_app_id=$(/usr/libexec/PlistBuddy -c 'Print :GOOGLE_APP_ID' "${source_plist}" 2>/dev/null || true)
  case "${google_app_id}" in *:ios:*) ;; *) echo "error: Firebase plist does not contain a native iOS GOOGLE_APP_ID." >&2; exit 1 ;; esac
  if [ "${actual_project}" != "${expected_project}" ] || [ "${actual_bundle}" != "${expected_bundle}" ]; then
    echo "error: Firebase plist must target ${expected_project} / ${expected_bundle}." >&2
    exit 1
  fi
fi

mkdir -p "$(dirname "${destination}")"
/usr/bin/cp "${source_plist}" "${destination}"
