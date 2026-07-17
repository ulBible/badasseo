#!/usr/bin/env bash
set -euo pipefail

# Builds and packages the Mac App Store variant (BadasseoAppStore target:
# sandboxed — see Resources/Badasseo-AppStore.entitlements) into an
# uploadable .pkg.
#
# STATUS (Task 6 / Plan 5 handoff): this script builds and assembles the
# sandboxed .app skeleton end to end, including local self-signed smoke
# signing (--sandbox-smoke) so the sandbox can be exercised before any Apple
# certs exist. The DISTRIBUTION signing path below (Apple Distribution cert,
# provisioning profile, productbuild .pkg) is NOT implemented yet — that is
# Plan 5's job, once the vClips App Store re-review lands and MAS submission
# is actually scheduled. Search for "TODO(plan-5)" below.
#
# One-time setup for distribution (Plan 5, not done here):
#   1. Certificates (Xcode → Settings… → Accounts → Manage Certificates… → +):
#      "Apple Distribution" AND "Mac Installer Distribution".
#   2. Provisioning profile: developer.apple.com → Profiles → new "Mac App
#      Store Connect" distribution profile for app.badasseo.mas; download and
#      save as Resources/BadasseoAppStore.provisionprofile (gitignored).
#   3. App Store Connect: create the app record for app.badasseo.mas.
#
# Usage:
#   ./scripts/appstore.sh <version>                  # distribution .pkg (not yet implemented — see TODO(plan-5))
#   ./scripts/appstore.sh <version> --sandbox-smoke  # local self-signed build
#                                                    # for testing the sandbox

VERSION="${1:?usage: appstore.sh <version> [--sandbox-smoke]}"
MODE="${2:-dist}"
APP_NAME="Badasseo"
TARGET="BadasseoAppStore"
BUNDLE_ID="app.badasseo.mas"
APP_BUNDLE="build/${APP_NAME}-AppStore.app"
DERIVED_DATA=".xcbuild"
BUILD_DIR="${DERIVED_DATA}/Build/Products/Release"
DIST_DIR="dist"
PROFILE="Resources/BadasseoAppStore.provisionprofile"

cd "$(dirname "$0")/.."

if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: xcodebuild requires full Xcode (active developer dir: $(xcode-select -p))." >&2
  exit 1
fi

echo "==> Building (Release via xcodebuild, scheme ${TARGET})"
xcodebuild -quiet \
  -scheme "${TARGET}" \
  -configuration Release \
  -destination "platform=macOS" \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS" "${APP_BUNDLE}/Contents/Resources"
cp "${BUILD_DIR}/${TARGET}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info-AppStore.plist" "${APP_BUNDLE}/Contents/Info.plist"
# TODO(plan-5): Badasseo has no AppIcon.icns yet (bundle.sh doesn't ship one
# either) — add `cp "Resources/AppIcon.icns" ...` here once one exists.

# Package resource bundles (BadasseoAppKit's sound-*.wav etc.), found via
# Bundle.main.resourceURL at runtime — same logic as scripts/bundle.sh.
copied_bundles=0
for resource_bundle in "${BUILD_DIR}"/*.bundle; do
  [[ -e "${resource_bundle}" ]] || continue
  cp -R "${resource_bundle}" "${APP_BUNDLE}/Contents/Resources/"
  copied_bundles=$((copied_bundles + 1))
done
if [[ "${copied_bundles}" -eq 0 ]]; then
  echo "error: no package resource bundles found in ${BUILD_DIR} — the derived-data layout may have changed." >&2
  exit 1
fi

# whisper.cpp ships as a dynamic XCFramework; embed it and point @rpath at
# Contents/Frameworks, same as scripts/bundle.sh — without this the app
# fails to launch (dyld: Library not loaded: @rpath/whisper.framework).
WHISPER_FRAMEWORK=""
for candidate in "${BUILD_DIR}/whisper.framework" "${BUILD_DIR}/PackageFrameworks/whisper.framework"; do
  [[ -d "${candidate}" ]] && WHISPER_FRAMEWORK="${candidate}" && break
done
if [[ -z "${WHISPER_FRAMEWORK}" ]]; then
  echo "error: whisper.framework not found in ${BUILD_DIR} — the app would crash at launch (dyld)." >&2
  exit 1
fi
mkdir -p "${APP_BUNDLE}/Contents/Frameworks"
cp -R "${WHISPER_FRAMEWORK}" "${APP_BUNDLE}/Contents/Frameworks/"
install_name_tool -add_rpath "@executable_path/../Frameworks" \
  "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

PLIST="${APP_BUNDLE}/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" "${PLIST}"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(git rev-list --count HEAD)" "${PLIST}"
# App Store binaries with no encryption beyond HTTPS: skip the export
# compliance questionnaire on every upload.
/usr/libexec/PlistBuddy -c "Add :ITSAppUsesNonExemptEncryption bool false" "${PLIST}" 2>/dev/null || true

if [[ "${MODE}" == "--sandbox-smoke" ]]; then
  echo "==> Sandbox smoke signing (self-signed; NOT uploadable)"
  SIGN_IDENTITY="${BADASSEO_SIGN_IDENTITY:-}"
  if [[ -z "${SIGN_IDENTITY}" ]]; then
    if security find-identity -v -p codesigning 2>/dev/null | grep -q "Badasseo Self Signed"; then
      SIGN_IDENTITY="Badasseo Self Signed"
    else
      SIGN_IDENTITY="-"
    fi
  fi
  codesign --force --deep --sign "${SIGN_IDENTITY}" \
    --entitlements "Resources/Badasseo-AppStore.entitlements" "${APP_BUNDLE}"
  echo "==> Done (smoke): ${APP_BUNDLE} — launch it to test sandboxed behavior"
  exit 0
fi

# --- Distribution signing (TODO(plan-5): not implemented) ---
# The pieces this needs, once certs/profile exist (see header):
#   1. Find "Apple Distribution" identity via `security find-identity`.
#   2. Find "Mac Installer Distribution" / "3rd Party Mac Developer
#      Installer" identity for productbuild.
#   3. Copy ${PROFILE} to ${APP_BUNDLE}/Contents/embedded.provisionprofile.
#   4. `xattr -cr` the bundle (strips com.apple.quarantine — App Store
#      processing rejects it with error 91109 if it survives).
#   5. `codesign --force --timestamp --sign <dist-id> --entitlements
#      Resources/Badasseo-AppStore.entitlements ${APP_BUNDLE}`, then
#      `codesign --verify --strict`.
#   6. `productbuild --component ${APP_BUNDLE} /Applications --sign
#      <installer-id> dist/${APP_NAME}-AppStore-${VERSION}.pkg`.
# See vClips' scripts/appstore.sh (this script's template) for a full
# reference implementation of steps 1-6.
echo "error: distribution signing not implemented yet (TODO(plan-5)) — run with --sandbox-smoke for a local unsigned/self-signed test build." >&2
exit 1
