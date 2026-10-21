# Restore easy utilities corner hover

The user reported that opening the bottom-right utility board required precise aiming after the desktop frame was removed. The drawer mask had a 32×32 trigger, while Interactions still calculated activation from border thickness/rounding and the hidden panel's visible height. That coupled an invisible trigger to the removed decorative border.

Utilities now owns a 96×64 activation area shared by Regions and Interactions. Opening is independent of border dimensions. The visible board remains a hover target; a 180ms leave grace prevents accidental collapse during pointer travel. Shortcut-opened board behavior is retained. The trigger respects the utilities enabled setting and remains excluded from fullscreen input regions.

Native validation exercised three points across the activation area on each output, moving into the board, leaving it and resting outside the activation area: 20 checks passed on eDP-1 and HDMI-A-1. Initial probes destroyed their virtual pointer before checking hover; the corrected probes keep it alive while measuring. Their final results are in `Backups/utilities-corner-20261020/runtime-results.json`. No new QML warnings/errors after correcting the screen-scoped config lookup; the existing qtengine watcher warning remains. A later MPRIS ServiceUnknown warning came from a media endpoint disappearing, separately from the corner handling. Diff whitespace checked clean.

Pre-change copies of the three edited files are in `/home/dorriss/Backups/utilities-corner-20261020/modules/`; the task-only comparison is `changes.patch` in that directory. Temporary diagnostics were removed. Original pointer/output focus were restored, and Keep Awake remains enabled.
