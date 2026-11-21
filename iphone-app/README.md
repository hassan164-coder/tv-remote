# TV Remote — iPhone app for your Samsung TV

A native iPhone remote for Samsung Tizen TVs (tested design target: QE65QN90A, 2021).
It connects to the TV over your home Wi‑Fi using the TV's secure remote API on port 8002,
and trusts the TV's self-made certificate **only for the IP address you enter**.

## What you need
- A Mac with **Xcode** (free in the Mac App Store, version 16 or newer)
- Your iPhone and a cable
- Your Apple ID (a free one works)

## Install (first time, ~15 minutes plus the Xcode download)

1. **Open the project.** Unzip, then double-click `TVRemote.xcodeproj`. Xcode opens.
2. **Sign in.** Xcode menu → Settings → Accounts → `+` → Apple ID → sign in.
3. **Pick your team.** In the left sidebar click the blue **TVRemote** project icon → under TARGETS click **TVRemote** → tab **Signing & Capabilities** → **Team**: choose *Your Name (Personal Team)*.
   - If you see "Failed to register bundle identifier": change **Bundle Identifier** to something unique, e.g. `com.yourname.tvremote2`.
4. **Connect your iPhone** with the cable. Unlock it and tap **Trust** if asked.
5. **Turn on Developer Mode** (only once): iPhone Settings → Privacy & Security → scroll to the bottom → **Developer Mode** → On → restart → confirm **Turn On**.
   (The option only appears after the iPhone has been connected to Xcode.)
6. **Choose your iPhone** in the device menu at the top-middle of the Xcode window.
7. **Press ▶ (Run)** or ⌘R. The first build takes a minute.
8. If the iPhone says **"Untrusted Developer"**: Settings → General → **VPN & Device Management** → your Apple ID → **Trust**. Then open the app again.

## First use
1. Open **TV Remote**. The setup screen opens.
2. Type the TV's IP address (TV: Settings → General → Network → Network Status → IP Settings).
3. Tap **Connect**.
4. The iPhone asks to **find devices on your local network** → tap **Allow**. (If the first try fails right after this popup, just tap Connect again.)
5. Look at the TV and press **Allow** with the normal remote.
6. The dot turns green. The pairing is saved — next time it connects by itself.

## Good to know
- **Free Apple ID = 7 days.** After 7 days the app stops opening. Plug in, press ▶ in Xcode again, done. A paid Apple Developer account ($99/yr) makes it last a year.
- **Power ON** usually doesn't work: when the TV is fully off, its network is off too. Power OFF works.
- **Hold** the arrows, volume or channel buttons to repeat.
- **Type tab:** open a search box on the TV first, then send text from the phone.

## Troubleshooting
| Problem | Fix |
|---|---|
| "Can't reach the TV" | Check the IP. iPhone and TV on the same Wi‑Fi (not a guest network). |
| Fails right after the Local Network popup | Tap Connect again. If you tapped "Don't Allow": iPhone Settings → TV Remote → turn on **Local Network**. |
| "The TV refused" | TV: Settings → General → External Device Manager → Device Connection Manager → Device List → allow "iPhone Remote". Then in the app: Forget pairing → Connect. |
| Xcode says the project is damaged / won't open | Make a new project instead: File → New → Project → iOS App, name `TVRemote`, Interface SwiftUI. Drag the three `.swift` files from the `TVRemote` folder into it (replace the generated ones). Then target → **Info** tab → add **Privacy - Local Network Usage Description** with any text, and **App Transport Security Settings** → **Allows Local Networking** = YES. If you get concurrency errors, set Build Settings → **Default Actor Isolation** to *nonisolated*. |

The log at the bottom of the app's setup screen shows exactly what the TV answered — send it over if something fails.
