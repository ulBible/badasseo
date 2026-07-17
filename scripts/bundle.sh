#!/usr/bin/env bash
set -euo pipefail

CONFIG="${1:-release}"
APP_NAME="Badasseo"
APP_BUNDLE="build/${APP_NAME}.app"
DERIVED_DATA=".xcbuild"

# Build with xcodebuild, not `swift build`. The two build systems generate
# different Bundle.module accessors for package resources (KeyboardShortcuts
# localizations): SwiftPM's variant only searches the app-bundle ROOT — where
# codesign forbids extra files ("unsealed contents present in the bundle
# root") — plus this machine's absolute build path, so an app assembled from
# a `swift build` binary fatal-errors on any other Mac the moment a package
# resource loads (e.g. opening Settings). Xcode's variant searches
# Contents/Resources, which is both signable and portable.
case "${CONFIG}" in
  release) XCODE_CONFIG="Release" ;;
  debug) XCODE_CONFIG="Debug" ;;
  *) echo "Unknown config '${CONFIG}' (expected release or debug)"; exit 1 ;;
esac
BUILD_DIR="${DERIVED_DATA}/Build/Products/${XCODE_CONFIG}"

# Code-signing identity.
# A stable identity (e.g. a self-signed "Badasseo Self Signed" cert) keeps the
# app's Designated Requirement constant across rebuilds, so the macOS
# Accessibility (auto-paste) permission persists instead of resetting every
# build the way ad-hoc signing does. Falls back to ad-hoc ("-") if no stable
# identity is available. Override with BADASSEO_SIGN_IDENTITY.
SIGN_IDENTITY="${BADASSEO_SIGN_IDENTITY:-}"
if [[ -z "${SIGN_IDENTITY}" ]]; then
  if security find-identity -v -p codesigning 2>/dev/null | grep -q "Badasseo Self Signed"; then
    SIGN_IDENTITY="Badasseo Self Signed"
  else
    SIGN_IDENTITY="-"
  fi
fi

# xcodebuild needs a full Xcode; with only Command Line Tools selected it
# fails with a confusing error, so check up front with a pointer to the fix.
if ! xcodebuild -version >/dev/null 2>&1; then
  echo "error: xcodebuild requires full Xcode (active developer dir: $(xcode-select -p))." >&2
  echo "Install Xcode, then: sudo xcode-select -s /Applications/Xcode.app/Contents/Developer" >&2
  exit 1
fi

echo "==> Building (${XCODE_CONFIG} via xcodebuild)"
xcodebuild -quiet \
  -scheme "${APP_NAME}" \
  -configuration "${XCODE_CONFIG}" \
  -destination "platform=macOS" \
  -derivedDataPath "${DERIVED_DATA}" \
  CODE_SIGNING_ALLOWED=NO \
  build

echo "==> Assembling ${APP_BUNDLE}"
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"
cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

# Package resource bundles, found via Bundle.main.resourceURL at runtime.
copied_bundles=0
for resource_bundle in "${BUILD_DIR}"/*.bundle; do
  [[ -e "${resource_bundle}" ]] || continue
  cp -R "${resource_bundle}" "${APP_BUNDLE}/Contents/Resources/"
  copied_bundles=$((copied_bundles + 1))
done
# An app without its package resource bundles launches here (the dev .build
# fallback exists) but fatal-errors on every other Mac — fail loudly instead.
if [[ "${copied_bundles}" -eq 0 ]]; then
  echo "error: no package resource bundles found in ${BUILD_DIR} — the derived-data layout may have changed." >&2
  exit 1
fi

# whisper.cpp ships as a dynamic XCFramework (see Package.swift's `whisper`
# binaryTarget); embed it and point @rpath at Contents/Frameworks, which the
# SwiftPM-built executable doesn't carry by default. Without this the app
# fails to launch at all (dyld: Library not loaded: @rpath/whisper.framework).
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
# add_rpath fails if the entry already exists — harmless, so tolerate it.
install_name_tool -add_rpath "@executable_path/../Frameworks" \
  "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}" 2>/dev/null || true

# Sparkle is a dynamic framework (binary xcframework artifact), linked only
# into the Badasseo (GitHub) target — see Package.swift. Embed it the same
# way as whisper.framework above; without this the GitHub build fails to
# launch (dyld: Library not loaded: @rpath/Sparkle.framework). The App Store
# build (scripts/appstore.sh, scheme BadasseoAppStore) never links Sparkle,
# so no Sparkle.framework exists in ITS build products to copy — the
# exclusion is automatic, not something appstore.sh has to filter out.
SPARKLE_FRAMEWORK=""
for candidate in "${BUILD_DIR}/Sparkle.framework" "${BUILD_DIR}/PackageFrameworks/Sparkle.framework"; do
  [[ -d "${candidate}" ]] && SPARKLE_FRAMEWORK="${candidate}" && break
done
if [[ -z "${SPARKLE_FRAMEWORK}" ]]; then
  echo "error: Sparkle.framework not found in ${BUILD_DIR} — auto-updates would crash the app at launch." >&2
  exit 1
fi
cp -R "${SPARKLE_FRAMEWORK}" "${APP_BUNDLE}/Contents/Frameworks/"

if [[ "${SIGN_IDENTITY}" == "-" ]]; then
  echo "==> Ad-hoc code signing (no stable identity found — Accessibility grant will reset each build)"
else
  echo "==> Code signing with identity: ${SIGN_IDENTITY}"
fi
codesign --force --deep --sign "${SIGN_IDENTITY}" "${APP_BUNDLE}"

echo "==> Done: ${APP_BUNDLE}"

if [[ "${2:-}" == "install" ]]; then
  echo "==> Installing to /Applications"
  rm -rf "/Applications/${APP_NAME}.app"
  cp -R "${APP_BUNDLE}" "/Applications/${APP_NAME}.app"
  echo "==> Installed: /Applications/${APP_NAME}.app"
fi
