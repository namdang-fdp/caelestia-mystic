pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils
import "../modules/dashboard/helpers/HomeLogic.js" as Logic

Singleton {
    id: root
    property bool loaded
    readonly property var order: Logic.order(adapter.order)
    readonly property var disabled: Logic.list(adapter.disabled)
    function visibleModules(hasShelf: bool, showMedia: bool, hasAgent: bool): var { return Logic.visible(order, disabled, hasShelf, showMedia, hasAgent); }
    function toggle(id: string): void {
        if (!loaded || !order.includes(id)) return;
        adapter.disabled = disabled.includes(id) ? disabled.filter(v => v !== id) : [...disabled, id];
    }
    function moveTo(id: string, index: int): void { if (loaded) adapter.order = Logic.moveTo(order, id, index); }
    function move(id: string, direction: int): void { if (loaded) adapter.order = Logic.move(order, id, direction); }
    Timer { id: save; interval: 300; onTriggered: preferences.writeAdapter() }
    FileView {
        id: preferences
        path: `${Paths.state}/island-home.json`
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: save.restart()
        onLoaded: root.loaded = true
        onLoadFailed: error => { root.loaded = true; if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: adapter
            property var order: ["media", "timer", "agent", "battery", "notes", "shelf"]
            property var disabled: []
        }
    }
}
