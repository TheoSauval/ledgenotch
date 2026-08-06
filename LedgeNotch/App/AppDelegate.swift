import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var notchController: NotchController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        notchController = NotchController()
        notchController?.start()
        installStatusItem()

        if DebugOptions.openSettings {
            DispatchQueue.main.async {
                MainActor.assumeIsolated { SettingsWindow.open() }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        notchController?.stop()
    }

    /// Sans icône dans le Dock, il faut bien un moyen de quitter l'app et
    /// d'ouvrir les réglages : un petit élément dans la barre de menus.
    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "rectangle.topthird.inset.filled",
            accessibilityDescription: "LedgeNotch"
        )

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Réglages…",
            action: #selector(openSettings),
            keyEquivalent: ","
        ).target = self
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Quitter LedgeNotch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() {
        SettingsWindow.open()
    }
}
