# Appearance settings — 2026-10-17

The existing Wallpaper & style settings now cover launcher appearance actions while retaining the launcher.

- Colours & theme provides searchable scheme/flavour cards with palette samples, random themes, dark/light mode, all nine Material 3 variants, and the smart wallpaper colour setting.
- Theme changes use the existing Caelestia CLI and share the launcher's scheme/variant catalogue. A persistent service serializes commands and lets an application finish after the page closes. The saved scheme file drives the selected state; failed commands are reported inline.
- Wallpapers and category pages preview a choice without saving it, offer Apply/Cancel, and restore the prior wallpaper and colours on exit. Browse, random selection and featured wallpapers use the same preview flow. Loading/invalid images cannot be applied.
- New choices and actions support keyboard activation and accessible labels. Layouts adapt to narrow settings content.

## Preview race regression

Previously, a colour calculation finishing after cancellation enabled the preview palette again. The preview service now ignores cancelled/stale results and processes the latest requested image after an in-flight request. The colour lock is released after the saved wallpaper updates.

Run the isolated, non-persisting service checks in the desktop session:

```sh
python3 tests/wallpaper-preview.py
```

All three checks passed: late cancellation, latest-image colour correctness, and saved-wallpaper preservation. The cancellation failure was reproduced before the fix.

## Runtime verification

Using the installed Quickshell/Caelestia libraries in a temporary QML harness:

- Applied a preset scheme, wallpaper-derived colours, light/dark modes and an expressive Material 3 variant.
- Rejected an invalid scheme and an unsupported light mode with inline errors.
- Confirmed theme application completes after leaving Colours.
- Applied a wallpaper and restored the previous wallpaper.
- Verified mouse and Space activation of the tab controls, plus 960px and 520px content layouts.
- Parsed the edited QML and checked git whitespace.

Loaded the change in the main shell; settings open and the launcher still toggles. Restored the initial dynamic/hard/dark/tonalspot appearance and kept the session's Keep Awake setting enabled. No package update or launcher keybinding change was made.

The original working tree, shell configuration and appearance state are backed up under `~/.local/state/caelestia/backups/settings-appearance-20261017/`. That directory also contains detailed runtime results and the temporary UI harness used during verification. Earlier unrelated uncommitted changes remain outside these commits.
