# Island phase 2 — Home overview and pinned clipboard

Implemented the second batch selected after the NotchIsland comparison, on top of the uncommitted phase 1 changes.

## Home

- Home is the first carousel page and appears on a left click when the resting island has no more specific activity. Hover still previews the existing current activity/glance. Right click continues to open Controls; middle click opens Windows.
- Music and Timer share a row when adjacent; either fills a row when alone. Music reuses the existing player controls; Timer offers start 25 minutes, pause and resume.
- Battery/device levels, today's calendar note and a contextual file shelf use the existing services. Shelf appears only when it contains files. Info opened from Home returns to Home.
- Customize enables/disables cards and moves them up or down. Choices are saved to `$XDG_STATE_HOME/caelestia/island-home.json`. The narrow layout becomes one column; overflow scrolls. An empty Home retains enough height for the page menu.
- A restart regression was found and fixed: JsonAdapter returns QML sequence objects that fail JavaScript Array.isArray. Home preferences now normalize those sequences before using them.

## Clipboard

- Filters: All, Pinned, Text, Images, Links, Code. Type detection is a label heuristic; search combines with the chosen filter.
- Pin text/images from each row; saved items appear first and survive recent-history eviction and shell restarts. Unpin removes the saved copy and retains the original history entry if it still exists.
- Pinned payloads and metadata live in `$XDG_STATE_HOME/caelestia/island-clipboard-pins/`, with a private directory (0700) and files (0600). Limits: 40 pins, 32 MiB per item. Payload hashes deduplicate saved data; numeric and pinned IDs are validated before use.
- Pinning and copying preserve original bytes, including binary images. Existing image thumbnails, refresh, keyboard search/selection/copy and deletion of regular history entries remain available. No new clipboard watcher was introduced.

## Verification

- 32 Node tests passed (activity, audio, Home), including four new Home tests.
- 19 Python tests passed (clipboard and temperature), including four new clipboard tests. New tests failed before their implementations/fixes.
- Native QML checks passed for Home/contextual shelf, customizing visibility/order, all four content filters, pins plus text search, and Enter copying a pinned image. The copied image matched the fixture bytes exactly.
- A separate shell instance verified saved Home choices and pins after restart, unpinning without deleting original history, empty/narrow Home layouts, page-menu Escape behavior, and Home → Info → Back navigation.
- Native clipboard checks used a private cliphist database, private state/cache and a wl-copy shim. No user clipboard payload or history entry was changed by those tests. The first image fixture had a bad PNG checksum; it was replaced with a generated valid PNG and image rendering was verified on the successful run.
- Inspected Home, customization, pinned clipboard and narrow-layout screenshots. Final native runs had no TypeError, ReferenceError, binding loop or image decoding error.
- Loaded the final configuration in the main shell. Home, Controls, Media, Timer and Clipboard opened through IPC with valid geometry. The panels were closed after checking.
- `git diff --check` passed. Existing missing app/tray icon and SVG buffer warnings remain outside this change. Fractional scaling and physical device changes were not exercised.

## Recovery and evidence

Before-edit files and the initial working-tree patch are in `/home/dorriss/Backups/island-phase2-20261107/before/`; evidence is in its `evidence/` directory. No commit was created; prior phase 1 and unrelated pending changes remain intact.

To undo phase 2, restore the existing source files from `before/` and remove IslandHomeView.qml, IslandHome.qml, helpers/HomeLogic.js and helpers/test_home.cjs, then restart the shell. Keep saved pin data and Home preferences unless explicitly choosing to remove them.
