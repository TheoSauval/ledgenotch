import AppKit

/// Point d'entrée AppKit, plutôt qu'un `App` SwiftUI.
///
/// LedgeNotch n'a aucune fenêtre au sens de SwiftUI : son interface est un panneau
/// flottant posé sur l'encoche. Le modèle App/Scene imposerait une scène factice,
/// et surtout sa scène `Settings` refuse d'ouvrir sa fenêtre tant que l'app tourne
/// en `.accessory` — l'action est bien reçue, mais rien n'apparaît. On gère donc
/// le cycle de vie et les fenêtres directement.
@main
enum LedgeNotchMain {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        _ = application.setActivationPolicy(.accessory)
        application.run()
    }
}
