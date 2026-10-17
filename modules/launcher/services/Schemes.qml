pragma Singleton

import ".."
import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

Searcher {
    id: root

    property string currentScheme
    property string currentVariant
    property string catalogError
    readonly property bool catalogLoading: getSchemes.running

    function reloadCatalog(): void {
        catalogError = "";
        getSchemes.running = true;
    }

    function transformSearch(search: string): string {
        return search.slice(`${GlobalConfig.launcher.actionPrefix}scheme `.length);
    }

    function selector(item: var): string {
        return `${item.name} ${item.flavour}`;
    }

    function reload(): void {
        getCurrent.running = true;
    }

    list: schemes.instances
    useFuzzy: GlobalConfig.launcher.useFuzzy.schemes
    keys: ["name", "flavour"]
    weights: [0.9, 0.1]

    Variants {
        id: schemes

        Scheme {}
    }

    Process {
        id: getSchemes

        running: true
        command: ["caelestia", "scheme", "list"]
        onExited: (code, status) => {
            if (code !== 0 || status !== 0)
                root.catalogError = qsTr("Could not load colour schemes. Try refreshing the list.");
        }
        stdout: StdioCollector {
            onStreamFinished: {
                let schemeData;
                try {
                    schemeData = JSON.parse(text);
                } catch (error) {
                    root.catalogError = qsTr("Could not load colour schemes. Try refreshing the list.");
                    return;
                }
                const list = Object.entries(schemeData).map(([name, f]) => Object.entries(f).map(([flavour, colours]) => ({
                                name,
                                flavour,
                                colours
                            })));

                const flat = [];
                for (const s of list)
                    for (const f of s)
                        flat.push(f);

                schemes.model = flat.sort((a, b) => String(a.name + a.flavour).localeCompare((b.name + b.flavour)));
            }
        }
    }

    Process {
        id: getCurrent

        running: true
        command: ["caelestia", "scheme", "get", "-nfv"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [name, flavour, variant] = text.trim().split("\n");
                root.currentScheme = `${name} ${flavour}`;
                root.currentVariant = variant;
            }
        }
    }

    component Scheme: QtObject {
        required property var modelData
        readonly property string name: modelData.name
        readonly property string flavour: modelData.flavour
        readonly property var colours: modelData.colours

        function onClicked(list: AppList): void {
            list.screenState.launcher = false;
            Quickshell.execDetached(["caelestia", "scheme", "set", "-n", name, "-f", flavour]);
        }
    }
}
