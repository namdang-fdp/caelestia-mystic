pragma Singleton
import Quickshell
import Quickshell.Services.SystemTray
import Caelestia.Config

Singleton {
    // Keep the existing StatusNotifier host alive even when its view is unloaded.
    readonly property var items: SystemTray.items.values.filter(item => !GlobalConfig.bar.tray.hiddenIcons.includes(item.id))
}
