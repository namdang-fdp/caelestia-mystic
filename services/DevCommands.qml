pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/dashboard/helpers/DevLogic.js" as Logic

// Long-running terminal commands, reported by the zsh hook (shell-hook.zsh):
//   qs -c caelestia ipc call devcmd done <exit> <seconds> <command> <shell pid>
Singleton {
    id: root
    signal finished(int code, int seconds, string command, int pid)

    IpcHandler {
        target: "devcmd"
        function done(code: int, seconds: int, command: string, pid: int): void {
            if (!Logic.validExit(code) || !Logic.validSeconds(seconds)) return;
            root.finished(code, seconds, command, pid);
        }
    }
}
