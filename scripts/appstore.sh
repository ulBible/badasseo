#!/usr/bin/env bash
set -euo pipefail

# Builds and packages the Mac App Store variant (BadasseoAppStore target:
# sandboxed — see Resources/Badasseo-AppStore.entitlements) into an
# uploadable .pkg.
#
# STATUS: fully implemented — both --sandbox-smoke (self-signed local test)
# and the distribution path (Apple Distribution + provisioning profile +
# productbuild .pkg, vClips-pattern). Distribution needs the one-time setup
# below; it fails with a clear message on whichever piece is missing.
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
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

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
# MAS SAFETY: copy frameworks by explicit name only — NEVER a *.framework
# wildcard. bundle.sh shares this derived-data dir and leaves Sparkle.framework
# there; embedding Sparkle in the MAS build is an App Review rejection.
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
  # 자리표시자(TEAM_ID) 키가 남아 있으면 자가서명에서 TCC 신원이 어긋난다 —
  # application-identifier/team-identifier를 뺀 사본으로 서명.
  SMOKE_ENT="$(mktemp -t badasseo-smoke).entitlements"
  plutil -convert xml1 -o "${SMOKE_ENT}" "Resources/Badasseo-AppStore.entitlements"
  /usr/libexec/PlistBuddy -c "Delete :com.apple.application-identifier" "${SMOKE_ENT}" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Delete :com.apple.developer.team-identifier" "${SMOKE_ENT}" 2>/dev/null || true
  codesign --force --deep --sign "${SIGN_IDENTITY}" \
    --entitlements "${SMOKE_ENT}" "${APP_BUNDLE}"
  echo "==> Done (smoke): ${APP_BUNDLE} — launch it to test sandboxed behavior"
  exit 0
fi

# --- Distribution signing (vClips scripts/appstore.sh와 동일 패턴) ---
DIST_ID=$(security find-identity -v -p codesigning 2>/dev/null \
  | grep -m1 "Apple Distribution" | sed -E 's/.*"(.+)"$/\1/' || true)
if [[ -z "${DIST_ID}" ]]; then
  echo "error: no 'Apple Distribution' certificate — create it in Xcode (see header)." >&2
  exit 1
fi
# Installer identity lives in the keychain but not under codesigning policy.
INSTALLER_ID=$(security find-identity -v 2>/dev/null \
  | grep -m1 -E "(3rd Party Mac Developer Installer|Mac Installer Distribution)" \
  | sed -E 's/.*"(.+)"$/\1/' || true)
if [[ -z "${INSTALLER_ID}" ]]; then
  echo "error: no installer certificate ('Mac Installer Distribution') — create it in Xcode (see header)." >&2
  exit 1
fi
TEAM_ID=$(sed -E 's/.*\(([A-Z0-9]+)\)$/\1/' <<<"${DIST_ID}")

if [[ ! -f "${PROFILE}" ]]; then
  echo "error: provisioning profile missing at ${PROFILE} (see header, step 2)." >&2
  exit 1
fi
cp "${PROFILE}" "${APP_BUNDLE}/Contents/embedded.provisionprofile"

# Browser-downloaded files (like the provisioning profile) carry
# com.apple.quarantine, which App Store processing rejects with error 91109
# if it survives inside the package — strip every xattr from the bundle.
xattr -cr "${APP_BUNDLE}"

ENT="$(mktemp -t badasseo-mas).entitlements"
sed -e "s/TEAM_ID/${TEAM_ID}/g" -e "s/BUNDLE_ID/${BUNDLE_ID}/g" \
  Resources/Badasseo-AppStore.entitlements > "${ENT}"

echo "==> Signing with: ${DIST_ID} (team ${TEAM_ID})"
# whisper.framework은 중첩 코드라 먼저(inside-out) 배포 신원으로 서명해야 한다.
codesign --force --timestamp --sign "${DIST_ID}" \
  "${APP_BUNDLE}/Contents/Frameworks/whisper.framework"
codesign --force --timestamp --sign "${DIST_ID}" --entitlements "${ENT}" "${APP_BUNDLE}"
codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

echo "==> Building installer package"
mkdir -p "${DIST_DIR}"
PKG="${DIST_DIR}/${APP_NAME}-AppStore-${VERSION}.pkg"
rm -f "${PKG}"
productbuild --component "${APP_BUNDLE}" /Applications \
  --sign "${INSTALLER_ID}" "${PKG}"

echo "==> Done: ${PKG}"
echo "Upload with the Transporter app, then submit for review in App Store Connect."
