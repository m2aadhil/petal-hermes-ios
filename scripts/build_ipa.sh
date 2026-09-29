#!/usr/bin/env bash
# Build a signed, installable IPA for on-device testing.
#
#   scripts/build_ipa.sh                     # development IPA, team from the project
#   METHOD=release-testing scripts/build_ipa.sh   # ad-hoc IPA
#   TEAM_ID=ABCDE12345 BUNDLE_ID=com.you.hermes scripts/build_ipa.sh
#
# Requires Xcode, a signed-in Apple Developer account (Xcode → Settings → Accounts)
# and, for development/ad-hoc, the test devices registered to the team.
# Output: build/ipa/Petal.ipa
set -euo pipefail
cd "$(dirname "$0")/.."

TEAM_ID="${TEAM_ID:-$(grep -m1 -oE 'DEVELOPMENT_TEAM = [A-Z0-9]{10}' Petal.xcodeproj/project.pbxproj | awk '{print $3}' || true)}"
METHOD="${METHOD:-debugging}"          # debugging (development) | release-testing (ad-hoc)
CONFIGURATION="${CONFIGURATION:-Release}"
OUT="build/ipa"

if [[ -z "${TEAM_ID}" ]]; then
  echo "No team ID found. Set one in Xcode (Signing & Capabilities) or run: TEAM_ID=XXXXXXXXXX $0" >&2
  exit 1
fi

extra=()
[[ -n "${BUNDLE_ID:-}" ]] && extra+=("PRODUCT_BUNDLE_IDENTIFIER=${BUNDLE_ID}")

rm -rf "$OUT"; mkdir -p "$OUT"
echo "▸ Archiving ($CONFIGURATION, team $TEAM_ID)…"
xcodebuild -project Petal.xcodeproj -scheme Petal -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' -archivePath "$OUT/Petal.xcarchive" \
  DEVELOPMENT_TEAM="$TEAM_ID" CODE_SIGN_STYLE=Automatic ${extra[@]+"${extra[@]}"} \
  -allowProvisioningUpdates archive | { command -v xcpretty >/dev/null && xcpretty || cat; }

cat > "$OUT/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>${METHOD}</string>
  <key>teamID</key><string>${TEAM_ID}</string>
  <key>signingStyle</key><string>automatic</string>
  <key>thinning</key><string>&lt;none&gt;</string>
</dict></plist>
PLIST

echo "▸ Exporting IPA ($METHOD)…"
xcodebuild -exportArchive -archivePath "$OUT/Petal.xcarchive" -exportPath "$OUT" \
  -exportOptionsPlist "$OUT/ExportOptions.plist" -allowProvisioningUpdates

echo "✓ $(ls "$OUT"/*.ipa)"
