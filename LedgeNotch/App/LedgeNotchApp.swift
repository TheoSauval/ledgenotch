import SwiftUI

@main
struct LedgeNotchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // L'app n'a pas de fenêtre principale (LSUIElement = YES dans les réglages
        // de build) : tout se joue dans le panneau posé sur l'encoche. La scène
        // Settings donne quand même accès à ⌘, pour les préférences.
        Settings {
            SettingsView()
        }
    }
}
