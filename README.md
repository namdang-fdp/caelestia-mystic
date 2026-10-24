# caelestia-mystic

My Quickshell rice for Hyprland, built on top of the [caelestia](https://github.com/caelestia-dots/shell) shell.

![caelestia-mystic preview](assets/showcase/preview.gif)

🎬 **[Watch the full showcase (1920×1200, 60fps, ~2 min)](https://github.com/namdang-fdp/caelestia-mystic/releases/tag/showcase-2026-10-22)**

## Highlights

- **Dynamic Island**: compact pill that morphs into media (live audio visualiser, synced lyrics), controls, info, clipboard, weather, timer, windows and power pages
  - OSD with level bars for volume, brightness and charging; transient pills for Bluetooth devices, workspaces and track changes
  - Scroll over the pill to change volume, scroll sideways (or Shift+scroll) to switch between clock, lyrics and system stats
  - Countdown and Pomodoro timer that lives in the pill
  - Calendar notes, weather forecast, clipboard image previews and night light (hyprsunset/gammastep)
  - Wi-Fi and Bluetooth pages: inline password entry, known/nearby networks, pairing, device battery, forget
- **Notification centre**: popups (click to open the app, images, urgent styling) and grouped history inside the island
- **macOS-style dock**: pinned and running apps, drag to reorder, window previews, badges, plus Claude and Codex plan usage tiles
- **Lock screen**: clean island-style lock with blurred wallpaper, now playing, fingerprint hints and private notification count
- **Monitor profiles**: laptop/external/dual layouts with auto mode and clamshell switching
- **Nexus settings**: wallpaper and style, audio, panels, apps and more
- **Dynamic colours**: palette regenerates from the wallpaper
- **Utilities panel**: keep awake, screen recorder, quick toggles

## Install

Clone into the Quickshell config directory and run it:

```sh
git clone https://github.com/namdang-fdp/caelestia-mystic ~/.config/quickshell/caelestia
qs -c caelestia
```

## IPC

```sh
qs -c caelestia ipc call dynamicIsland open wifi        # controls, media, wifi, bluetooth, timer, weather, clipboard, ...
qs -c caelestia ipc call islandTimer start 25           # minutes; also: pomodoro, toggle, stop, status
qs -c caelestia ipc call monitorProfiles lid
```

