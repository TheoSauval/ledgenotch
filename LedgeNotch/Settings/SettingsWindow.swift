import AppKit
import SwiftUI

/// Gère la fenêtre de réglages.
///
/// L'app tourne en `.accessory` (pas d'icône dans le Dock). Dans cet état, macOS
/// refuse de la passer au premier plan : la fenêtre s'ouvrirait sans jamais se
/// montrer. On repasse donc en `.regular` le temps de la consultation, puis on
/// revient en arrière à la fermeture — sinon l'icône resterait dans le Dock pour
/// toute la session.
@MainActor
enum SettingsWindow {
    private static var window: NSWindow?
    private static var closeObserver: NSObjectProtocol?

    static func open() {
        _ = NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        let window = self.window ?? make()
        self.window = window
        window.makeKeyAndOrderFront(nil)
    }

    private static func make() -> NSWindow {
        let controller = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: controller)
        window.title = "Réglages de LedgeNotch"
        window.styleMask = [.titled, .closable, .miniaturizable]
        window.isReleasedWhenClosed = false
        // `center()` viserait l'écran principal au sens d'AppKit, qui n'est pas
        // forcément celui qui porte l'encoche : sur un poste à plusieurs écrans,
        // les réglages s'ouvriraient loin de l'encoche qu'on vient de cliquer.
        center(window, on: NotchGeometry.preferredScreen())

        closeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                _ = NSApp.setActivationPolicy(.accessory)
            }
        }

        return window
    }

    private static func center(_ window: NSWindow, on screen: NSScreen?) {
        guard let screen else {
            window.center()
            return
        }
        let visible = screen.visibleFrame
        let size = window.frame.size
        window.setFrameOrigin(
            NSPoint(
                x: visible.midX - size.width / 2,
                // Un peu au-dessus du centre géométrique : une fenêtre calée
                // pile au milieu paraît trop basse.
                y: visible.midY - size.height / 2 + visible.height * 0.08
            )
        )
    }
}
