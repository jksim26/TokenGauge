#!/bin/bash
# Installs (or with "remove", uninstalls) the launchd job that runs renew.sh every hour.
# renew.sh itself only reinstalls when the 7-day signature has fewer than 4 days left.
set -euo pipefail
LABEL=io.github.jksim26.TokenGauge.renew
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
if [ "${1:-}" = remove ]; then rm -f "$PLIST"; echo "Removed the renewal job."; exit 0; fi
SCRIPT="$(cd "$(dirname "$0")" && pwd)/renew.sh"
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key><array><string>/bin/bash</string><string>$SCRIPT</string></array>
  <key>StartInterval</key><integer>3600</integer>
  <key>RunAtLoad</key><true/>
  <key>ProcessType</key><string>Background</string>
</dict></plist>
PLIST
launchctl bootstrap "gui/$(id -u)" "$PLIST"
echo "Renewal job installed. Log: ~/Library/Logs/TokenGauge-renew.log"
