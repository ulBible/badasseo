#!/usr/bin/env bash
set -euo pipefail

# Creates a stable self-signed code-signing identity ("Badasseo Self Signed") in
# the login keychain. Signing the app with a stable identity (instead of ad-hoc)
# keeps its codesign Designated Requirement constant across rebuilds, so the
# macOS Accessibility permission that powers auto-paste persists instead of
# resetting on every build.
#
# Run once per machine. Idempotent: exits early if the identity already exists.
# It modifies your login keychain and adds a user-domain code-signing trust
# setting; macOS may show a confirmation dialog.

IDENTITY_NAME="Badasseo Self Signed"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning 2>/dev/null | grep -q "${IDENTITY_NAME}"; then
  echo "==> Identity '${IDENTITY_NAME}' already present. Nothing to do."
  exit 0
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "${WORKDIR}"' EXIT
KEY="${WORKDIR}/key.pem"
CERT="${WORKDIR}/cert.pem"
P12="${WORKDIR}/cert.p12"
P12_PASS="badasseo"

echo "==> Generating self-signed code-signing certificate"
openssl req -x509 -newkey rsa:2048 -keyout "${KEY}" -out "${CERT}" -nodes -days 3650 \
  -subj "/CN=${IDENTITY_NAME}/O=Badasseo" \
  -addext "basicConstraints=critical,CA:false" \
  -addext "keyUsage=critical,digitalSignature" \
  -addext "extendedKeyUsage=critical,codeSigning"

openssl pkcs12 -export -inkey "${KEY}" -in "${CERT}" -out "${P12}" \
  -passout "pass:${P12_PASS}" -name "${IDENTITY_NAME}"

echo "==> Importing into login keychain (grants /usr/bin/codesign access)"
security import "${P12}" -k "${KEYCHAIN}" -P "${P12_PASS}" -T /usr/bin/codesign

echo "==> Trusting the certificate for the code-signing policy (user domain)"
security add-trusted-cert -r trustRoot -p codeSign -k "${KEYCHAIN}" "${CERT}"

echo "==> Done. Valid code-signing identities:"
security find-identity -v -p codesigning
echo
echo "Now rebuild so the app is signed with this identity:"
echo "    ./scripts/bundle.sh release install"
echo "Then grant Accessibility to /Applications/Badasseo.app once; it will persist."
