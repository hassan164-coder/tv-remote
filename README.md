# TV Remote

A web-based remote for Samsung smart TVs (Tizen, 2016 and newer). It runs in Safari on iPhone, so nothing needs to be installed.

**Open it:** https://hassan164-coder.github.io/tv-remote/

## First-time setup

1. Make sure your iPhone and TV are on the same Wi‑Fi, and the TV is on.
2. Open the link above in Safari.
3. Enter the TV's IP address (TV: Settings → General → Network → Network Status → IP Settings).
4. Tap **Open TV certificate page**, then in Safari tap **Show Details → visit this website → Visit Website**. This lets Safari trust the TV's own security certificate.
5. Go back and tap **Connect**, then press **Allow** on the TV.
6. Optional: Share → **Add to Home Screen** for a full-screen app.

## How it works

The page opens a secure WebSocket to the TV's built-in remote API (`wss://<tv-ip>:8002/api/v2/channels/samsung.remote.control`) and sends key presses as JSON. The TV hands out a pairing token on first connect, and the page saves it in the browser so you only press Allow once.

## Limits

- Power **on** usually doesn't work, because the TV's network is off when the TV is fully off. Power off works.
- App buttons only open apps already installed on the TV.
