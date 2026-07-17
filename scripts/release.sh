#!/usr/bin/env bash
set -euo pipefail

# Builds, Developer ID-signs, notarizes, staples, and packages Badasseo for
# public distribution (GitHub Releases). Local dev builds are covered by
# scripts/bundle.sh with a self-signed identity; this script re-signs its
# output for Gatekeeper. Model is NOT bundled — the app downloads it on first
# run, so the zip stays small. Mirrors vClips' scripts/release.sh (same
# Sparkle EdDSA key pair, same zip + generate_appcast flow) now that the
# GitHub build embeds Sparkle.framework (see scripts/bundle.sh).
#
# One-time setup: same as vClips (Developer ID Application cert + notarytool
# keychain profile). Reuses the vclips-notary profile by default since the
# credentials are account-level, not per-app.
#
# Usage:
#   ./scripts/release.sh <version>          e.g. ./scripts/release.sh 1.0.0
#
# Environment overrides:
#   BADASSEO_DEV_ID          full signing identity; auto-detected when exactly
#                            one "Developer ID Application" cert exists
#   BADASSEO_NOTARY_PROFILE  notarytool keychain profile (default: vclips-notary)

VERSION="${1:?usage: release.sh <version> (e.g. 1.0.0)}"
APP_NAME="Badasseo"
APP_BUNDLE="build/${APP_NAME}.app"
NOTARY_PROFILE="${BADASSEO_NOTARY_PROFILE:-vclips-notary}"
DIST_DIR="dist"
ZIP_PATH="${DIST_DIR}/${APP_NAME}-${VERSION}.zip"

cd "$(dirname "$0")/.."

# Resolve the Developer ID identity up front so we fail before the (slow)
# build when signing can't succeed anyway.
DEV_ID="${BADASSEO_DEV_ID:-}"
if [[ -z "${DEV_ID}" ]]; then
  matches=$(security find-identity -v -p codesigning 2>/dev/null \
    | grep "Developer ID Application" || true)
  count=$(grep -c . <<<"${matches}" || true)
  if [[ -z "${matches}" ]]; then
    echo "error: no 'Developer ID Application' certificate in the keychain." >&2
    exit 1
  elif [[ "${count}" -gt 1 ]]; then
    echo "error: multiple Developer ID certificates — pick one via BADASSEO_DEV_ID:" >&2
    echo "${matches}" >&2
    exit 1
  fi
  DEV_ID=$(sed -E 's/.*"(.+)"$/\1/' <<<"${matches}")
fi

echo "==> Building ${APP_BUNDLE} (via bundle.sh)"
./scripts/bundle.sh release

echo "==> Stamping version ${VERSION}"
PB=/usr/libexec/PlistBuddy
PLIST="${APP_BUNDLE}/Contents/Info.plist"
${PB} -c "Set :CFBundleShortVersionString ${VERSION}" "${PLIST}" 2>/dev/null \
  || ${PB} -c "Add :CFBundleShortVersionString string ${VERSION}" "${PLIST}"
# Monotonic build number so macOS never considers a newer build "older".
BUILD_NUM=$(git rev-list --count HEAD)
${PB} -c "Set :CFBundleVersion ${BUILD_NUM}" "${PLIST}" 2>/dev/null \
  || ${PB} -c "Add :CFBundleVersion string ${BUILD_NUM}" "${PLIST}"

echo "==> Signing with: ${DEV_ID}"
# Sparkle's nested executables must each carry a hardened-runtime signature
# or notarization rejects the bundle. Inside-out order, per Sparkle's docs
# (same as vClips' release.sh).
SPARKLE_B="${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework/Versions/B"
for nested in \
  "${SPARKLE_B}/XPCServices/Installer.xpc" \
  "${SPARKLE_B}/XPCServices/Downloader.xpc" \
  "${SPARKLE_B}/Autoupdate" \
  "${SPARKLE_B}/Updater.app" \
  "${APP_BUNDLE}/Contents/Frameworks/Sparkle.framework"; do
  [[ -e "${nested}" ]] || continue
  codesign --force --options runtime --timestamp \
    --preserve-metadata=entitlements --sign "${DEV_ID}" "${nested}"
done
codesign --force --options runtime --timestamp \
  --sign "${DEV_ID}" "${APP_BUNDLE}/Contents/Frameworks/whisper.framework"
# Hardened runtime + secure timestamp are notarization requirements.
codesign --force --options runtime --timestamp \
  --sign "${DEV_ID}" "${APP_BUNDLE}"
codesign --verify --strict --verbose=2 "${APP_BUNDLE}"

echo "==> Notarizing (profile: ${NOTARY_PROFILE}) — takes a few minutes"
mkdir -p "${DIST_DIR}"
# Old zips would end up in the appcast (and get re-signed) — keep dist/ to
# exactly this release.
rm -f "${DIST_DIR}"/*.zip "${DIST_DIR}"/appcast.xml
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"
xcrun notarytool submit "${ZIP_PATH}" \
  --keychain-profile "${NOTARY_PROFILE}" --wait

echo "==> Stapling ticket"
xcrun stapler staple "${APP_BUNDLE}"

# Re-zip: stapling modified the .app, and the uploaded archive lacks the ticket.
rm -f "${ZIP_PATH}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo "==> Gatekeeper check"
spctl --assess --type exec --verbose=2 "${APP_BUNDLE}"

echo "==> Generating Sparkle appcast"
# The Sparkle SPM artifact ships the CLI tools; the EdDSA private key lives in
# the login keychain (same account-level key pair vClips uses — Badasseo's
# SUPublicEDKey in Resources/Info.plist matches).
APPCAST_TOOL=""
for candidate in \
  ".xcbuild/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
  ".build/artifacts/sparkle/Sparkle/bin/generate_appcast"; do
  [[ -x "${candidate}" ]] && APPCAST_TOOL="${candidate}" && break
done
if [[ -z "${APPCAST_TOOL}" ]]; then
  echo "error: generate_appcast not found — build once so SwiftPM fetches the Sparkle artifact." >&2
  exit 1
fi
"${APPCAST_TOOL}" "${DIST_DIR}" \
  --download-url-prefix "https://github.com/ulBible/badasseo/releases/download/v${VERSION}/" \
  --link "https://github.com/ulBible/badasseo"

echo "==> Done: ${ZIP_PATH} + ${DIST_DIR}/appcast.xml"
echo "Publish BOTH files (the app reads appcast.xml from the latest release):"
echo "  gh release create v${VERSION} ${ZIP_PATH} ${DIST_DIR}/appcast.xml"
