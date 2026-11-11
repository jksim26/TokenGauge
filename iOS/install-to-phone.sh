#!/bin/bash
# Builds Token Gauge and installs it on a connected, trusted iPhone (Developer Mode on).
# With a free Apple ID the install expires after 7 days: run this again to renew it.
# Needs: Xcode signed in to your Apple ID, xcodegen (brew install xcodegen), and iOS/Local.xcconfig
# with BUNDLE_PREFIX and DEVELOPMENT_TEAM set (copy Local.xcconfig.example).
set -euo pipefail
cd "$(dirname "$0")"
[ -f Local.xcconfig ] || { echo "Copy Local.xcconfig.example to Local.xcconfig and fill it in first."; exit 1; }
grep -Eq '^DEVELOPMENT_TEAM *= *[A-Z0-9]{10}' Local.xcconfig || { echo "Set DEVELOPMENT_TEAM in iOS/Local.xcconfig (Xcode > Settings > Accounts shows your team ID)."; exit 1; }
xcodegen generate --quiet
LIST=$(mktemp)
xcrun devicectl list devices --json-output "$LIST" >/dev/null
DEVICE=$(/usr/bin/python3 -I -c 'import json,sys
for d in json.load(open(sys.argv[1]))["result"]["devices"]:
    if d.get("hardwareProperties",{}).get("platform")=="iOS" and d.get("hardwareProperties",{}).get("reality")=="physical" and d.get("connectionProperties",{}).get("pairingState")=="paired":
        print(d["identifier"]); break' "$LIST")
rm -f "$LIST"
[ -n "$DEVICE" ] || { echo "No paired iPhone found. Connect it by cable, tap Trust, and turn on Developer Mode."; exit 1; }
BUILD_LOG=$(mktemp)
if ! xcodebuild -project TokenGauge.xcodeproj -scheme TokenGauge -configuration Debug -destination "id=$DEVICE" \
  -derivedDataPath build -allowProvisioningUpdates build > "$BUILD_LOG" 2>&1; then
  grep -E " error|BUILD" "$BUILD_LOG" || tail -5 "$BUILD_LOG"; rm -f "$BUILD_LOG"; echo "Build failed."; exit 1
fi
rm -f "$BUILD_LOG"
xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Debug-iphoneos/TokenGauge.app
echo "Installed. On first run, trust the developer on the iPhone: Settings > General > VPN & Device Management."
