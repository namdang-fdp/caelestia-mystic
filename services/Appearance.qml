pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.launcher.services

Singleton {
    id: root

    readonly property bool applying: applyProc.running
    property string errorMessage

    function apply(args: list<string>): void {
        if (applying)
            return;
        errorMessage = "";
        applyProc.command = ["caelestia", "scheme", "set", ...args];
        applyProc.running = true;
    }

    Process {
        id: applyProc

        onExited: (code, status) => {
            if (code !== 0 || status !== 0)
                root.errorMessage = qsTr("Could not apply this choice. The selected theme may not support this appearance mode.");
            Schemes.reload();
            Schemes.reloadCatalog();
        }
    }
}
