# PPPKeeper

A macOS menu bar app that keeps a PPP-over-hotspot connection alive.

It runs `bash <(curl -s http://192.168.49.1:8181/msh)` and reruns it whenever the
output shows `terminated with signal 15` or `Connection terminated`. It also reruns
it if the command exits. This continues until you click **Stop**.

Menu bar states: 🟢 connected (with uptime) · 🟡 connecting · 🟠 retrying · ⚪️ stopped.

## Build & run

```bash
./PPPKeeper/build.sh
open PPPKeeper/PPPKeeper.app
```

Click the menu bar item, then **Start**. macOS asks for your admin password once,
because pppd needs root.

## Without the menu bar

```bash
sudo ./PPPKeeper/keeper.sh
```

Press Ctrl+C to stop.

## Files

- `PPPKeeper/keeper.sh`: the reconnect loop. State and logs go in `~/Library/Application Support/PPPKeeper/`.
- `PPPKeeper/main.swift`: the menu bar app.
- `PPPKeeper/build.sh`: builds `PPPKeeper.app`.
