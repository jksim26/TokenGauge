#!/bin/bash
# Keeps the free-Apple-ID install alive: re-signs and reinstalls Token Gauge before its 7-day signature
# runs out. Run hourly by the launchd job that setup-renew.sh installs; does nothing while the signature
# still has more than RENEW_BEFORE_DAYS left. `FORCE=1 ./renew.sh` renews now.
set -uo pipefail
export PATH="/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
cd "$(dirname "$0")"
STATE="$HOME/Library/Application Support/Token Gauge"
LOG="$HOME/Library/Logs/TokenGauge-renew.log"
APP="build/Build/Products/Debug-iphoneos/TokenGauge.app"
PROFILES="$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles"
mkdir -p "$STATE"
now=$(date +%s)
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG"; }
field() { security cms -D -i "$1" 2>/dev/null | plutil -extract "$2" raw - 2>/dev/null; }
# Earliest expiry (epoch seconds) of the profiles in the last build that was installed; 0 if unknown.
expiry() {
    local earliest=0 f t
    for f in "$APP/embedded.mobileprovision" "$APP"/PlugIns/*.appex/embedded.mobileprovision; do
        [ -f "$f" ] || { echo 0; return; }
        t=$(date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$(field "$f" ExpirationDate)" +%s 2>/dev/null) || { echo 0; return; }
        if [ "$earliest" -eq 0 ] || [ "$t" -lt "$earliest" ]; then earliest=$t; fi
    done
    echo "$earliest"
}
left=$(( $(expiry) - now ))
last=$(cat "$STATE/renew-last-attempt" 2>/dev/null || echo 0)
if [ "${FORCE:-0}" != 1 ]; then
    [ "$left" -gt $(( ${RENEW_BEFORE_DAYS:-4} * 86400 )) ] && exit 0
    # Not urgent yet: one attempt every 6 hours. In the last day (or once expired): every run.
    [ "$left" -gt 86400 ] && [ $(( now - last )) -lt 21600 ] && exit 0
fi
echo "$now" > "$STATE/renew-last-attempt"
before=$(expiry)
# Xcode reuses its cached profile until it expires, so drop this app's cached profiles to get fresh ones.
prefix=$(sed -n 's/^BUNDLE_PREFIX *= *//p' Local.xcconfig | tr -d ' ')
for f in "$PROFILES"/*.mobileprovision; do
    [ -f "$f" ] || continue
    case "$(security cms -D -i "$f" 2>/dev/null | plutil -extract Entitlements.application-identifier raw - 2>/dev/null)" in
        *".$prefix.TokenGauge"|*".$prefix.TokenGauge.Widget") rm -f "$f" ;;
    esac
done
rm -rf "$APP" # never reinstall a stale build if the new one fails
out=$(./install-to-phone.sh 2>&1); status=$?
after=$(expiry)
if [ "$status" -eq 0 ] && [ "$after" -gt "$now" ]; then
    until=$(date -r "$after" '+%a %d %b %H:%M')
    if [ "$after" -gt "$before" ]; then log "renewed; signature valid until $until"; else log "reinstalled, but Apple reissued the same signature (valid until $until)"; fi
    rm -f "$STATE/renew-warned"
    exit 0
fi
log "FAILED (exit $status): $(echo "$out" | grep -vE 'warning:|^ *\||^ *[0-9]+ \|' | tail -4 | tr '\n' ' ')"
# Tell the user at most once a day, and only when the signature is close to running out.
warned=$(cat "$STATE/renew-warned" 2>/dev/null || echo 0)
if [ "$left" -lt $(( 2 * 86400 )) ] && [ $(( now - warned )) -gt 86400 ]; then
    echo "$now" > "$STATE/renew-warned"
    osascript -e 'display notification "Could not renew the iPhone app. Connect and unlock the iPhone; see ~/Library/Logs/TokenGauge-renew.log." with title "Token Gauge"' >/dev/null 2>&1
fi
exit 1
