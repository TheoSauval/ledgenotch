import AppKit

/// Réglages de mise au point, pilotés par variables d'environnement.
///
/// Itérer sur le contenu de l'encoche ouverte demanderait sinon de survoler puis
/// cliquer à chaque lancement. Dans Xcode : Product → Scheme → Edit Scheme →
/// Run → Arguments → Environment Variables.
enum DebugOptions {
    /// `LEDGENOTCH_FORCE_OPEN=1` ouvre l'encoche dès le lancement.
    static var forceOpen: Bool {
        ProcessInfo.processInfo.environment["LEDGENOTCH_FORCE_OPEN"] == "1"
    }

    /// `LEDGENOTCH_FORCE_PANEL=claude` choisit l'onglet affiché au lancement.
    static var forcedPanel: NotchState.Panel? {
        switch ProcessInfo.processInfo.environment["LEDGENOTCH_FORCE_PANEL"] {
        case "claude": return .claude
        case "home": return .home
        default: return nil
        }
    }

    /// `LEDGENOTCH_OPEN_SETTINGS=1` ouvre la fenêtre de réglages au lancement,
    /// pour itérer dessus sans repasser par l'engrenage à chaque fois.
    static var openSettings: Bool {
        ProcessInfo.processInfo.environment["LEDGENOTCH_OPEN_SETTINGS"] == "1"
    }

    /// `LEDGENOTCH_WINDOW_LEVEL=101` force le niveau du panneau, pour comparer
    /// ce qui passe devant ou derrière la barre de menus.
    static var windowLevel: NSWindow.Level? {
        guard
            let raw = ProcessInfo.processInfo.environment["LEDGENOTCH_WINDOW_LEVEL"],
            let value = Int(raw)
        else { return nil }
        return NSWindow.Level(rawValue: value)
    }
}
