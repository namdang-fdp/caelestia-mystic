# Follow-up: navigation, ThinkPad controls and workspace motion

Applied the user's follow-up feedback on 20 October 2026. This builds on the completed Tide implementation. Backups and native evidence are in `/home/dorriss/Backups/island-refine-20261020/`.

## Navigation

Super+Shift+I toggles Info; Super+Shift+W toggles Windows. Both use existing global-shortcut and Island page handling, switching directly from another page and closing when pressed again on the same page. Existing Super+I and right click still open Control Center.

The music player now offers Control Center at bottom left, Windows at bottom right, and Info through its clock. These work in hover preview and pin the requested page. Control Center includes explicit Info/Windows footer actions. Secondary page titles match Info and Windows.

## Slider diagnosis and changes

The user clarified that the affected display was the ThinkPad, so the laptop backlight was tested directly. Before the follow-up changes, native slider clicks on eDP-1 produced exactly 20% and 5% hardware brightness. No laptop backlight failure was reproduced. The previous control panel selected the output hosting the Island without displaying that target, which made the target ambiguous on this two-display setup.

The control panel now defaults to the internal ThinkPad display on either output and shows its name and percentage. Clicking the name cycles supported displays. Audio shows the actual default sink name (soundcore R50i NC during verification), its percentage and muted status; the main volume slider spans the normal 0–100% range.

Brightness commands now coalesce pending updates, serialize writes and read back hardware values. Internal commands explicitly select the backlight class. Unsupported external outputs cannot silently control the laptop. Failed writes report an error and revert to the confirmed value. An additional, separate Redmi issue was found: DDC reads 80%, while both the old shell and a direct setvcp attempt failed to change it. The new backend verifies and reports this failure; it is not presented as a ThinkPad fault.

`runtime-results.json` records 12 successful native checks: shortcut navigation/toggle, default ThinkPad target from the external output, backlight 20%/5%, actual PipeWire volume, detail panels and all three player navigation actions. `brightness-regression-results.json` records the final value surviving a rapid request sequence (17% UI/hardware), and a rejected DDC write returning to confirmed 80% with an error. Earlier diagnostics are in `thinkpad-before-results.json`; they established that the ThinkPad already accepted commands. One early navigation test clicked below the player clock; correcting that coordinate verified the real action without a product-code workaround.

The user's music remained playing. Brightness, audio volume, mute state and original output/workspaces were restored after each test.

## Connections and motion

Wi-Fi/Bluetooth details use small icon tiles, two-line device/network rows, a clear connected checkmark, subdued lock indicators and rounded rectangles. Header controls align at the right. Height follows the device count; a single Bluetooth device uses a ~172px panel instead of the previous 366px. Settings links remain available and the existing connection/password service path is preserved.

Workspace motion now uses a separate curve, 360ms duration and a short 12% slide with fade. The previous full-width slide reused a resize curve with a strongly front-loaded start. The new curve has a gentler start and substantially less travel. Native capture `workspace-motion.mp4` shows four switches on the ThinkPad at 1920×1200, 60fps. Temporary windows were closed afterwards. This verifies the configured transition and live capture, not a guarantee against every future rendering stall.

Lua syntax, live Hyprland configuration, task diff whitespace and QML runtime checked clean. No additional shell dependency or persistent polling was added. Reviewed command serialization/readback, loader/input-mask sizing for variable panel heights, page switching while previewing, unsupported displays and failure reporting. Existing unrelated pending work is preserved; no git commit was made.

## Sources and recovery

- [Official Hyprland animation parameters and workspace movement percentages](https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/).
- [Official ddcutil setvcp verification behavior](https://www.ddcutil.com/command_setvcp/).
- Native hardware reads, PipeWire state and interaction evidence in the backup directory.

`changes.patch` compares the eight edited runtime files with their exact pre-follow-up copies under `Backups/island-refine-20261020/.config/`. Restore those files to undo only this follow-up, then reload Hyprland and restart Quickshell. The earlier full implementation backup and shortcut guide remain in `Backups/tide-clean-20261020/`.

## Later user selection: option A

The user selected a subtle app pop-in: `windowsIn` is now `popin 97%`, with matching window fade-in at 350ms using the resize curve. Workspace duration was increased from 360ms to 550ms, retaining the short slide/fade. Changes applied live and checked through native app opening, workspace switching, live animation parameters and configuration errors. The earlier workspace recording above shows the 360ms version. The immediately previous config and current verification are in `/home/dorriss/Backups/hypr-motion-a-20261020/`.

The user found the initial option A too abrupt. Current opening uses only 99%→100% scale, 550ms fade/geometry, and a separate gentle-start curve `(0.33, 0, 0.67, 1)` instead of the front-loaded resize curve. Workspace remains at 550ms. The pre-adjustment config is saved in `/home/dorriss/Backups/hypr-motion-gentle-20261020/`.

Closing now mirrors the gentle opening: `windowsOut` uses `popin 99%` and `fadeOut` uses the same 550ms `tideOpen` curve. This replaces the downward closing slide following the user's request. Previous config: `/home/dorriss/Backups/hypr-motion-close-20261020/hypr-user-before.lua`.
