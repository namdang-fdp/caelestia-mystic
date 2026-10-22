# Island Geist and neutral depth — 20 October 2026

User direction: a cleaner macOS-like appearance, proportional Geist typography, deep neutral blacks and floating glass-like application surfaces, using the supplied Tide video as the visual reference.

Implemented:
- Bundle upstream Geist variable font and its OFL license in assets/fonts/geist. IslandTheme loads the local file with FontLoader; IslandText and the two input fields use this family. Terminal and other shell typography keep their existing configuration.
- Give Island its own neutral palette instead of the wallpaper-derived purple palette. Keep semantic battery and warning colours. Use a subtle dark surface gradient, a fine light rim and a separate RectangularShadow following the animated capsule geometry.
- Use charcoal selected buttons and white primary actions/slider fills. Adjust connected-device row text for the new selected-button surface. Rename the decorative Controls heading to Control Center.
- In ~/.config/caelestia/hypr-vars.lua, use a black 40% shadow, range 24, render power 3; rounding 14; blur passes 3; restrained white window borders. Existing app opacity values remain in use.

Verification:
- Actual Quickshell compiled and loaded the configuration; all eight Island pages opened with valid geometry and no QML errors in the new log.
- Controls visually checked on HDMI-A-1 and eDP-1. Existing reservations remain [10, 46, 10, 10] on both monitors. Screenshots saved in the backup directory.
- Hyprland reload succeeded, configerrors was empty; live shadow, blur and rounding options match the override file. Lua syntax check and git diff --check passed.
- Restored focused output HDMI-A-1, closed panel state, Controls selection and Keep Awake enabled. Page inspection did not invoke system-control or power actions.
- Visual-only change: no new behavioral tests added. Wi-Fi connection, audio mutation and power operations were not exercised.

Backup and review artifacts: /home/dorriss/Backups/island-geist-20261020/ (pre-task shell tarball, original user settings, source patch, font SHA-256, runtime results and screenshots). The repository was already dirty, including the existing Island files; previous changes were preserved and no unrelated work was committed.

Sources:
- https://github.com/vercel/geist-font (Geist font, bundled unmodified with OFL)
- https://github.com/enhaoswen/swen_hyprland_dotfile/blob/main/hypr/hyprland.conf (reference compositor styling)
- https://doc.qt.io/qt-6/qml-qtquick-fontloader.html
- https://doc.qt.io/qt-6/qml-qtquick-effects-rectangularshadow.html
