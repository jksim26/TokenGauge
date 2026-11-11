# Token Gauge on an iPhone, installed from a Windows PC

This guide is for someone who has an iPhone and a Windows PC, but no Mac. It is written so that a
person or a coding assistant (Codex, Claude Code) can follow it step by step.

Token Gauge shows how much of your Claude, Codex (ChatGPT) and Grok usage limits you have used, as
iPhone widgets. It is not on the App Store, so it is installed by "sideloading": a tool on your PC
signs the app with your own Apple ID and copies it to your phone.

**Status: the app is tested on an iPhone installed from a Mac. Installing from Windows has not been
tested yet. If a step fails, see "If something goes wrong" and report back what you saw.**

## What you need

- `TokenGauge.ipa` (the app file; you were sent it together with this guide)
- An iPhone on iOS 17 or later, and its USB cable
- A Windows 10 or 11 PC
- An Apple ID. The sideloading tool asks for its email and password. If you would rather not type
  your main Apple ID into a third-party tool, create a second Apple ID just for this.

## Limits you should know first

- **The app stops opening after 7 days** unless it is refreshed. This is Apple's rule for free
  Apple IDs. The tool refreshes it for you when your PC is on and the phone is on the same Wi-Fi.
- A free Apple ID can hold 3 sideloaded apps at a time. AltStore itself counts as one.
- Token Gauge reads usage through each provider's own unofficial endpoints. They can change without
  notice, and then you need a new `TokenGauge.ipa` from whoever sent you this one.

## Step 1: Install a sideloading tool on the PC

Use one of these. Both are free. Follow the tool's own current Windows instructions, because their
requirements change:

- **AltStore** (recommended; open source): https://altstore.io — follow "Get AltStore" for Windows.
  It installs "AltServer" on the PC and the "AltStore" app on the phone.
- **Sideloadly** (simpler, one window): https://sideloadly.io

Both need Apple's iTunes and iCloud for Windows installed, so the PC can talk to the iPhone. Their
install pages say which versions to use.

## Step 2: Prepare the iPhone

1. Connect the iPhone to the PC by cable. Unlock it and tap **Trust** when asked.
2. Turn on Developer Mode: **Settings > Privacy & Security > Developer Mode**, switch it on, and
   restart when asked. (The switch only appears after a sideloading tool has seen the phone once,
   so if you can't find it, do Step 3 first and come back.)

## Step 3: Install Token Gauge

**With AltStore**
1. Copy `TokenGauge.ipa` to the iPhone (for example save it to the Files app through iCloud Drive,
   or send it to yourself).
2. Open AltStore on the phone, go to **My Apps**, tap **+**, and choose `TokenGauge.ipa`.
3. Sign in with your Apple ID if asked, and wait for it to finish.

**With Sideloadly**
1. Open Sideloadly on the PC with the phone connected.
2. Drag `TokenGauge.ipa` into the window, enter your Apple ID, and click **Start**.
3. Leave the advanced options at their defaults. In particular, do **not** tick any option that
   removes app extensions or app groups: the widgets need both.

Then, on the iPhone, trust yourself as a developer:
**Settings > General > VPN & Device Management > (your Apple ID) > Trust**.

## Step 4: Sign in inside the app

Open Token Gauge and tap **Sign in** for each service you use.

- **Claude** and **Codex** open the system sign-in sheet, which shares Safari's saved logins. If
  you are already signed in to claude.ai or chatgpt.com in Safari, this takes a tap or two.
- **Grok** signs in on cursor.com inside the app (the Grok, Grok Bot and Cursor allowance is one
  shared pool, read from the Cursor account).

Your sign-ins are stored only in the iPhone's Keychain and sent only to the service they belong to.

## Step 5: Add the widgets

- **Home Screen:** touch and hold the Home Screen > **Edit** > **Add Widget** > search "Token Gauge".
  Small, medium and large sizes exist.
- **Lock Screen:** touch and hold the Lock Screen > **Customize** > the widget row > search
  "Token Gauge". There is one widget per service; a wide one takes two of the four slots.

Open the app once before looking for the widgets; iOS lists them only after that.

## Step 6: Keep it alive

- **AltStore:** leave AltServer running on the PC and turn on its option to start with Windows.
  When the PC and phone are on the same Wi-Fi, AltStore refreshes the app in the background. You can
  also open AltStore on the phone and tap **Refresh All** at any time.
- **Sideloadly:** enable its automatic refresh option when installing, or repeat Step 3 weekly.

If the app does expire, it just won't open. Refresh or reinstall it; you do not need to delete it.

## If something goes wrong

Please report which of these you see, with the exact error text.

| What you see | What to try |
|---|---|
| The install fails with an error about **app groups** or **entitlements** | Try the other tool. Report the error. |
| The app opens but **the widgets do not appear** in the widget list | Open the app once, wait a minute, restart the iPhone, then look again. |
| The app shows your usage but **the widgets stay empty** or say to sign in | The widget cannot read the app's sign-ins. Open the app (it refreshes the widget's data) and report this: it means the tool changed the shared storage in a way the app did not expect. |
| "Unable to verify app" / "Untrusted developer" | Do the Trust step at the end of Step 3, with the phone online. |
| A service says **Sign in again** | Sign out of that service in the app and sign in again. |
| A service says it was **blocked by a security challenge** | That provider refused the request from the phone. Report it; there is no fix on your side. |
| "Maximum number of apps" or "app IDs" error | A free Apple ID allows 3 sideloaded apps and 10 new app IDs per week. Remove another sideloaded app, or wait a week. |

## For a coding assistant reading this

- Everything here is manual GUI work on the user's PC and phone. Do not try to type the user's
  Apple ID password yourself; ask the user to enter it in the tool.
- Do not modify `TokenGauge.ipa`. The app already handles being re-signed: it finds the shared
  App Group from the signing profile the tool embeds, so no patching is needed.
- The source is at https://github.com/jksim26/TokenGauge (the `iOS/` folder). It can only be built
  on a Mac with Xcode, so on Windows the `.ipa` is the only way in.
