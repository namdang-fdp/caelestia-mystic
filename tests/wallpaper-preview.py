"""Exercise asynchronous preview cancellation without changing saved appearance.

Run in the desktop session: python3 tests/wallpaper-preview.py
Requires Quickshell and at least two local wallpapers.
"""

import json
from pathlib import Path
import subprocess
import tempfile
import time


REPO = Path(__file__).resolve().parents[1]
SHELL = """//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

ShellRoot {
    settings.watchFiles: false
    IpcHandler {
        target: "previewTest"
        function status(): string {
            return JSON.stringify({
                paths: Wallpapers.list.map(w => w.path),
                current: Wallpapers.actualCurrent,
                preview: Wallpapers.showPreview,
                colourPreview: Colours.showPreview,
                loading: Wallpapers.previewLoading,
                path: Wallpapers.colourPreviewPath,
                primary: Colours.preview.m3primary.toString()
            });
        }
        function select(path: string): void {
            // Enable the preview branch only in this isolated process.
            Colours.scheme = "dynamic";
            Wallpapers.preview(path);
        }
        function cancel(): void { Wallpapers.stopPreview(); }
    }
}
"""


def run():
    with tempfile.TemporaryDirectory(prefix="caelestia-preview-test-") as directory:
        root = Path(directory)
        for name in ("modules", "components", "services", "utils", "assets"):
            (root / name).symlink_to(REPO / name, target_is_directory=True)
        (root / "shell.qml").write_text(SHELL)
        with (root / "log.txt").open("w+") as log:
            proc = subprocess.Popen(["qs", "-p", str(root), "--no-color"], stdout=log, stderr=log)

            def call(method, *args):
                return subprocess.check_output(
                    ["qs", "-p", str(root), "ipc", "call", "previewTest", method, *args],
                    text=True, stderr=subprocess.DEVNULL,
                ).strip()

            def status():
                return json.loads(call("status"))

            def wait_for(predicate):
                deadline = time.monotonic() + 10
                latest = None
                while time.monotonic() < deadline:
                    try:
                        latest = status()
                        if predicate(latest):
                            return latest
                    except (subprocess.CalledProcessError, json.JSONDecodeError):
                        pass
                    time.sleep(0.05)
                raise AssertionError(f"Timed out: {latest}")

            try:
                initial = wait_for(lambda s: len(s["paths"]) >= 2 and bool(s["current"]))
                first, second = initial["paths"][:2]
                call("select", first)
                call("cancel")
                cancelled = wait_for(lambda s: not s["loading"])
                assert not cancelled["preview"] and not cancelled["colourPreview"], cancelled
                print("PASS: cancelling ignores the late colour result")

                expected = json.loads(subprocess.check_output(["caelestia", "wallpaper", "-p", second], text=True))
                call("select", first)
                call("select", second)
                latest = wait_for(lambda s: not s["loading"] and s["colourPreview"] and s["path"] == second and s["primary"].lower() == f"#{expected['colours']['primary']}".lower())
                assert latest["current"] == initial["current"], latest
                print("PASS: rapid selection uses the latest image's colours")

                call("cancel")
                final = wait_for(lambda s: not s["preview"] and not s["colourPreview"])
                assert final["current"] == initial["current"], final
                print("PASS: preview never changes the saved wallpaper")
            finally:
                proc.terminate()
                proc.wait(timeout=5)


if __name__ == "__main__":
    run()
