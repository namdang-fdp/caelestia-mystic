pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Short per-day notes for the island calendar, keyed by local "YYYY-MM-DD".
Singleton {
    id: root

    readonly property int maximumLength: 280
    readonly property var notes: adapter.notes
    property bool loaded

    function key(date: date): string {
        const pad = n => String(n).padStart(2, "0");
        return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
    }
    function noteFor(date: date): string {
        return notes[key(date)] ?? "";
    }
    function hasNote(date: date): bool {
        return !!notes[key(date)];
    }
    function setNote(date: date, text: string): void {
        const value = text.trim().slice(0, maximumLength);
        const id = key(date);
        if ((notes[id] ?? "") === value) return;
        const next = Object.assign({}, notes);
        if (value) next[id] = value;
        else delete next[id];
        adapter.notes = next;
    }

    // Rapid edits are coalesced into one atomic write (back-to-back writes can be dropped).
    Timer { id: saveDelay; interval: 300; onTriggered: notesFile.writeAdapter() }

    FileView {
        id: notesFile
        path: `${Paths.state}/island-calendar-notes.json`
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.loaded = true
        onAdapterUpdated: saveDelay.restart()
        onLoadFailed: err => {
            root.loaded = true;
            if (err === FileViewError.FileNotFound) writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property var notes: ({})
        }
    }
}
