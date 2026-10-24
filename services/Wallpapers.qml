pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.Models
import qs.services
import qs.utils

Searcher {
    id: root

    readonly property string currentNamePath: `${Paths.state}/wallpaper/path.txt`
    readonly property list<string> smartArg: GlobalConfig.services.smartScheme ? [] : ["--no-smart"]
    readonly property string fallback: Quickshell.shellPath("assets/wallpaper.webp")

    property bool showPreview: false
    readonly property string current: showPreview ? previewPath : actualCurrent
    property string previewPath
    property string colourPreviewPath
    property string actualCurrent
    property bool previewColourLock
    property bool pendingPreviewClear
    property string queuedSetPath
    readonly property bool previewLoading: getPreviewColoursProc.running

    function getCategoryFor(w: FileSystemEntry): string {
        let category = w.parentDir.slice(Paths.wallsdir.length + 1);
        if (category.includes("/"))
            category = category.slice(0, category.indexOf("/"));
        return category;
    }

    function setRandom(): void {
        Quickshell.execDetached(["caelestia", "wallpaper", "-r", ...smartArg]);
    }

    function setWallpaper(path: string): void {
        actualCurrent = path;
        lockReleaseGrace.stop();
        if (setWallpaperProc.running) {
            queuedSetPath = path;
            return;
        }
        setWallpaperProc.command = ["caelestia", "wallpaper", "-f", path, ...smartArg];
        setWallpaperProc.running = true;
    }

    // The preview palette is normally released when path.txt reloads, but that never
    // happens if the CLI fails (or sets the same path), so also release it here.
    function handleSetExited(exitCode: int): void {
        if (exitCode !== 0) {
            console.warn("Could not set wallpaper:", setWallpaperStderr.text.trim() || `exit code ${exitCode}`);
            currentNameFile.reload();
            previewColourLock = false;
        } else if (previewColourLock) {
            // Let the scheme/path watchers catch up before dropping the preview palette.
            lockReleaseGrace.restart();
        }

        if (queuedSetPath) {
            const path = queuedSetPath;
            queuedSetPath = "";
            setWallpaper(path);
        }
    }

    function preview(path: string): void {
        previewPath = path;
        showPreview = true;

        if (Colours.scheme === "dynamic" && !getPreviewColoursProc.running)
            startColourPreview();
    }

    function startColourPreview(): void {
        colourPreviewPath = previewPath;
        getPreviewColoursProc.running = true;
    }

    function stopPreview(): void {
        showPreview = false;
        if (previewColourLock)
            pendingPreviewClear = true;
        else
            Colours.showPreview = false;
    }

    onPreviewColourLockChanged: {
        if (previewColourLock)
            lockTimeout.restart();
        else
            lockTimeout.stop();
        if (!previewColourLock && pendingPreviewClear) {
            pendingPreviewClear = false;
            Colours.showPreview = false;
        }
    }

    list: wallpapers.entries
    key: "relativePath"
    useFuzzy: GlobalConfig.launcher.useFuzzy.wallpapers
    extraOpts: useFuzzy ? ({}) : ({
            forward: false
        })

    IpcHandler {
        function get(): string {
            return root.actualCurrent;
        }

        function set(path: string): void {
            root.setWallpaper(path);
        }

        function list(): string {
            return root.list.map(w => w.path).join("\n");
        }

        target: "wallpaper"
    }

    FileView {
        id: currentNameFile

        path: root.currentNamePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            let wall = text().trim();
            if (!wall) {
                wall = root.fallback;
                Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
            }
            root.actualCurrent = wall;
            root.previewColourLock = false;
        }
        onLoadFailed: {
            root.actualCurrent = root.fallback;
            root.previewColourLock = false;
            Quickshell.execDetached(["caelestia", "wallpaper", "-f", root.fallback, ...root.smartArg]);
        }
    }

    FileSystemModel {
        id: wallpapers

        recursive: true
        path: Paths.wallsdir
        filter: FileSystemModel.Images
    }

    Process {
        id: setWallpaperProc

        stderr: StdioCollector {
            id: setWallpaperStderr
        }
        onExited: exitCode => root.handleSetExited(exitCode)
    }

    Timer {
        id: lockReleaseGrace

        interval: 1500
        onTriggered: root.previewColourLock = false
    }

    // Fallback so a hung CLI can never pin the preview palette for the session.
    Timer {
        id: lockTimeout

        interval: 10000
        onTriggered: root.previewColourLock = false
    }

    Process {
        id: getPreviewColoursProc

        command: ["caelestia", "wallpaper", "-p", root.colourPreviewPath, ...root.smartArg]
        onExited: {
            if (root.showPreview && Colours.scheme === "dynamic" && root.previewPath !== root.colourPreviewPath)
                root.startColourPreview();
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.showPreview || Colours.scheme !== "dynamic" || root.previewPath !== root.colourPreviewPath)
                    return;
                try {
                    Colours.load(text, true);
                } catch (error) {
                    console.warn("Could not preview wallpaper colours:", error);
                    return;
                }
                Colours.showPreview = true;
            }
        }
    }
}
