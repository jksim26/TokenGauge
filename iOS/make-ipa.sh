#!/bin/bash
# Builds dist/TokenGauge.ipa: an app file with no Apple ID attached, for someone without a Mac to
# install with AltStore or Sideloadly (see INSTALL-WINDOWS.md). The tool signs it with their Apple ID.
set -euo pipefail
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:$PATH"
xcodegen generate --quiet
LOG=$(mktemp)
if ! xcodebuild -project TokenGauge.xcodeproj -scheme TokenGauge -configuration Release -sdk iphoneos \
  -derivedDataPath build/ipa CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= build > "$LOG" 2>&1; then
  grep -E " error|BUILD" "$LOG" || tail -5 "$LOG"; rm -f "$LOG"; echo "Build failed."; exit 1
fi
rm -f "$LOG"
PREFIX=$(sed -n 's/^BUNDLE_PREFIX *= *//p' Local.xcconfig | tr -d ' ')
WORK=$(mktemp -d)
mkdir "$WORK/Payload"
cp -R build/ipa/Build/Products/Release-iphoneos/TokenGauge.app "$WORK/Payload/"
APP="$WORK/Payload/TokenGauge.app"
# Ad-hoc signature carrying only the entitlements, so the sideloading tool knows the app and widget share a group.
cat > "$WORK/ent.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.application-groups</key><array><string>group.$PREFIX.TokenGauge</string></array>
</dict></plist>
PLIST
codesign --force --sign - --entitlements "$WORK/ent.plist" "$APP/PlugIns/TokenGaugeWidget.appex"
codesign --force --sign - --entitlements "$WORK/ent.plist" "$APP"
mkdir -p dist
rm -f dist/TokenGauge.ipa
(cd "$WORK" && zip -qry out.ipa Payload) && mv "$WORK/out.ipa" dist/TokenGauge.ipa
rm -rf "$WORK"
echo "Wrote $(pwd)/dist/TokenGauge.ipa"
