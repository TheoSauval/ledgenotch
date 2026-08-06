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
