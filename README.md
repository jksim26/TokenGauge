# Token Gauge for macOS

A local WidgetKit widget for Apple's widget gallery, desktop and Notification Centre. Requires macOS 14 or later, Xcode command-line tools, Node.js, and a signed-in Codex CLI. Grok is optional and needs Grok Bot. Built for this Mac; no Apple developer account or provisioning profile is embedded.

## Use

1. Double-click **Install.command** if reinstalling or rebuilding. The initial install is performed during setup.
2. Open **Token Gauge** from your Applications folder.
3. Click the menu-bar date and time, choose **Edit Widgets**, search **Token Gauge**, and add the small, medium or large widget.
4. Claude and Codex must already be signed in. Claude usage first uses the existing Claude Desktop session; Claude Code Keychain sign-in is a fallback. If a sign-in expires, open the corresponding coding app to let it renew its own sign-in.
5. Optional Grok gauge: install and sign in to Grok Bot, open it once so it shows its weekly usage, then run Install.command again. Grok, Grok Bot and Cursor share one usage pool, so one gauge covers all three.

The small companion app previews the data and offers **Refresh**. A per-user helper runs at login and polls Claude and Codex every three minutes; closing the companion app does not stop it. The widget requests a timeline every three minutes, subject to macOS scheduling and refresh budgets. Tap the widget to open the companion app. Refresh requests a new timeline, but macOS ultimately schedules rendering.

## What the gauges mean

- Percentages represent quota **used**, not remaining. Claude uses an orange gradient, Codex a blue gradient and Grok Grok's monochrome (white on dark, near-black on light); these are provider colours rather than green/amber/red severity colours.
- The outlined coral marker represents the fraction of the quota window elapsed when that widget timeline entry was generated. Both marker strokes fit inside the usage track. Claude’s inner Fable track shares the main weekly pace reference.
- Text below each ring shows the local reset clock time, such as 11:59pm; weekly windows include the weekday, such as Thu 11:59pm.
- A clock indicates the last locally captured report is over 15 minutes old. Claude's capture time may be newer than the underlying server response when Claude Code re-runs its status line while idle.
- A dash means missing usage or a past reset. The app never infers zero usage after a reset.
- The gallery snapshot requests live data from the helper. A placeholder uses neutral rings until that snapshot is ready. The large widget includes per-provider source details.

## Data sources and privacy

**Codex:** Starts the installed Codex app-server, sends initialize / initialized / account/rateLimits/read, saves only primary/secondary percentages, durations, reset times and a local capture timestamp, then stops the child process. It uses the CLI's existing managed sign-in; Token Gauge does not copy authentication files, run inference, or consume reset credits. An expired sign-in must be restored in Codex itself.

**Grok (shared Grok / Cursor pool):** Every three minutes the helper reads Grok Bot's own `weekly-usage.cache` display file under `~/Library/Application Support/Grok Bot/sand-client-persistence` (file names are base32-encoded keys). It saves only the weekly percent used, the reset time and the time Grok Bot last read them. Token Gauge never reads Grok Bot's sign-in tokens, `sand-secrets.json`, or makes any network request for Grok. Grok Bot refreshes this file only while it is open, so the capture time is Grok Bot's own reading time: the clock symbol appears when Grok Bot has not refreshed it for 15 minutes, and usage from Cursor or grok.com is not reflected until Grok Bot next updates. This is an undocumented internal file and may change with Grok Bot updates. Without Grok Bot installed, the widget keeps its two-provider layout.

**Claude:** Reads only Claude Desktop's `claude.ai` session and associated security cookies from its SQLite cookie store in read-only mode, decrypting with `Claude Safe Storage` in macOS Keychain. Cookies are re-read every three minutes and are only passed in memory to `https://claude.ai/api/organizations/{org}/usage`. The selected organization comes from Desktop's active organization cookie; when missing, a sole returned organization may be selected. No browser stores are scanned. Cookies, Keychain secrets, organization IDs and raw responses are never written to usage reports or printed. Requests use a small native macOS URLSession helper with ephemeral storage, refuse redirects, and pass cookies through stdin rather than command arguments. Native networking avoids the HTTP 403 challenge observed with Node/curl on this Mac. Only quota percentages, reset times, capture time and a non-sensitive source name are saved.

If Desktop cannot refresh, the existing Claude Code OAuth source remains a fallback. Both unavailable sources preserve the last successful report and display the Desktop failure reason. Expired sessions need renewal in their owning app. A Claude web security challenge is reported explicitly and is not solved by this helper; opening Desktop Settings > Usage may help, but a session valid inside Desktop is not guaranteed to work for external requests. Server rate limits back off polling. There is no inference call, token renewal, or Desktop sign-in modification. These usage endpoints are unofficial and may change.

Claude's original status line is restored after upgrading from the first build. Background polling supplies all quota windows, including Fable, independently of Claude Code's status-line refreshes. Explicit model-scoped percentages are used directly; weekly contribution shares are never mistaken for quota utilization.

The helper serves sanitized usage JSON only at http://127.0.0.1:43871/snapshot. It does not listen on Wi-Fi or publish data to a website. Browser origins are refused; other local applications can access this endpoint. The widget uses loopback networking instead of App Groups, avoiding a team identifier and provisioning requirement. The widget extension has sandbox + network-client entitlements only.

Saved reports, the previous status-line command, and a settings backup are under ~/Library/Application Support/Token Gauge. The launch agent is ~/Library/LaunchAgents/local.jksim.tokengauge.plist. Source lives in ~/TokenGauge.

## Remove

Close Token Gauge, remove the widget from Notification Centre, and double-click **Uninstall.command**. This stops/removes the helper and app and restores the previous Claude status-line configuration if the wrapper is still configured. Saved reports and the backup remain in the data folder for recovery. It does not overwrite subsequent unrelated Claude settings changes.

## Build and checks

Run python3 build.py to compile and ad-hoc sign both bundles. The macOS widget uses Foundation's _NSExtensionMain entry point while retaining Swift's widget entry metadata; using Swift's normal main as the process entry crashed ExtensionFoundation on this Mac. No Xcode project or developer portal login is needed. Run node --test Tests/bridge.test.cjs Tests/claude-desktop.test.cjs Tests/iphone.test.cjs for data handling, status-line pass-through and iPhone script checks.

## iPhone app (native, no Mac needed once installed)

Lock Screen: the app also adds one widget per provider (Claude usage, Codex usage, Grok usage). The Lock Screen row is four slots wide; a wide widget takes two slots and shows every window with its reset time, a round one takes one slot and shows the weekly window.

Keeping it installed: with a free Apple ID the install expires after 7 days. `iOS/setup-renew.sh` installs a launchd job that runs `iOS/renew.sh` hourly; it re-signs and reinstalls once fewer than 4 days are left (so about every 3 days), as long as the Mac is awake and the iPhone is reachable and has been unlocked. Log: `~/Library/Logs/TokenGauge-renew.log`. Remove with `iOS/setup-renew.sh remove`.

The `iOS/` folder is a native iPhone app with Home Screen widgets (small, medium, large). Unlike the Scriptable widget it signs in **on the phone** and fetches usage itself, so it works while the Mac is off. It is for local install only; it is not on the App Store.

- **Claude:** sign in on claude.ai inside the app; the app keeps the session cookie (plus Claude's security cookies) and calls `claude.ai/api/organizations/{org}/usage`, the same endpoint the Mac helper uses.
- **Codex:** "Sign in with ChatGPT" through the Codex CLI's public OAuth client in the system sign-in sheet. The redirect goes to a listener on `127.0.0.1:1455` inside the app. The phone gets its own tokens (renewed with its own refresh token) and calls `chatgpt.com/backend-api/wham/usage`. This is a separate sign-in from the Mac's Codex and does not disturb it.
- **Grok:** sign in on cursor.com inside the app; the app keeps the `WorkosCursorSessionToken` cookie and calls `cursor.com/api/dashboard/get-sand-usage-status` for the weekly pool shared by Grok, Grok Bot and Cursor.

Sign-ins are stored only in the iPhone Keychain (this device only, shared with the widget through the app's App Group) and sent only to the service they belong to. The widget fetches by itself on each timeline reload (requested every 15 minutes; iOS decides the real cadence), the app refreshes every three minutes while open, and a background refresh task runs when iOS allows. These are unofficial endpoints and sign-in flows that can change or break, and using another product's sign-in may be against that service's terms.

**Build and install** (Xcode with an Apple ID signed in; `brew install xcodegen`):
1. Copy `iOS/Local.xcconfig.example` to `iOS/Local.xcconfig`; set `BUNDLE_PREFIX` to something unique to you and `DEVELOPMENT_TEAM` to your team ID.
2. Simulator: `cd iOS && xcodegen && open TokenGauge.xcodeproj`, then Run. Launching with the argument `-sampleData` shows example gauges without signing in (simulator only).
3. iPhone: connect it, tap Trust, turn on Developer Mode, then run `iOS/install-to-phone.sh` (or press Run in Xcode with the phone selected). On first launch, trust the developer under Settings → General → VPN & Device Management.

With a free Apple ID the install expires after 7 days; run `iOS/install-to-phone.sh` again to renew it (sign-ins and data are kept). Parsing checks run on the Mac: see `Tests/IOSParsing.swift`.

## iPhone (Scriptable)

Requires the free Scriptable app on the iPhone, signed in to the same Apple ID with iCloud Drive turned on for Scriptable.

1. Run Install.command. If this Mac has Scriptable's iCloud folder, the installer copies **Token Gauge.js** there, and the helper publishes **Token Gauge.json** beside it after every three-minute poll.
2. On the iPhone, open Scriptable once and check that **Token Gauge** appears in the script list (iCloud may take a minute).
3. Add a Scriptable widget (small, medium or large) to the Home Screen, long-press it, choose **Edit Widget**, and set **Script** to **Token Gauge**.

The phone shows the same gauges, colours, pace markers and layouts as the Mac widget, with Grok on the left. The widget is always dark; to change that, long-press it, choose **Edit Widget**, and set **Parameter** to `auto` (follow the phone's appearance) or `light`. It makes no network requests and holds no sign-ins: it only reads the JSON from iCloud Drive. That file is the same sanitized snapshot served at the loopback endpoint (percentages, reset times, capture times and status messages) and does leave this Mac through iCloud Drive. The phone updates only while the Mac is awake and online, iCloud sync can add a short delay, and iOS decides how often Scriptable widgets refresh (often every 15–30 minutes). A clock marks a provider report over 15 minutes old; "Mac offline · 3:12pm" means the Mac has not published for 15 minutes and gives the time of its last report; the percentages stay as of that report while the red pace markers keep tracking the current time. The phone also keeps its own copy of the last good data outside iCloud, so the widget still shows the latest numbers when the Mac is off or iCloud has not synced. A percentage whose reset time has passed shows a dash, as on the Mac, because the old value no longer applies. Uninstall.command removes both files from Scriptable's iCloud folder. The script's source is iPhone/Token Gauge.js.

References:
- https://learn.chatgpt.com/docs/app-server
- https://code.claude.com/docs/en/statusline
- https://developer.apple.com/documentation/WidgetKit


## Update fixes

The installer stops only the Token Gauge app and its own widget process before replacing the installed bundle. A stale running extension caused macOS to reject timeline archives with a bundle-version mismatch, leaving completely blank tiles despite successful live-data requests. Both app and extension now use one shared build version. The installer does not reset the LaunchServices database or restart system widget services.


## Widget appearance

Provider logos replace wordmarks. The title and descriptive footer are removed. Claude and Codex have two gauges each; Grok has one weekly (7D) gauge. With Grok present, Grok always sits on the left: the medium widget fits all three providers side by side at slightly reduced scale, and the large and small widgets show Grok on the left with Claude stacked over Codex on the right. The small size omits reset text (it is still in each ring's tooltip and accessibility label). Fable is integrated into Claude’s weekly gauge. The small size uses F as the compact Fable label, while medium and large spell out Fable. Its percentage is below the weekly dial; only the main weekly percentage is inside the dual ring. Tooltips and accessibility labels identify both tracks.

Full-colour widgets use a translucent system material. macOS Clear appearance supplies the native Liquid Glass treatment and tints widget content; the widget adapts its ring contrast and logos for accented rendering instead of forcing brand colours through the system tint. The companion content preview uses a standard translucent material; the widget’s native glass treatment is supplied by macOS.

Provider logo asset attribution is in Assets/NOTICE.md.

The gauge fill uses a continuous linear colour gradient rather than a wrapping angular gradient, so the round cap has no colour discontinuity at 12 o’clock. Reset timestamps are normalized to second precision to avoid subsecond server jitter displaying the previous minute.


Desktop session decryption and source details were checked against the upstream CodexBar documentation: https://github.com/steipete/CodexBar/blob/main/docs/claude.md .
