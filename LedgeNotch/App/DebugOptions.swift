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

    /// `LEDGENOTCH_FORCE_PHASE=peek` fige l'encoche dans un état donné.
    ///
    /// Le survol est le seul état qu'on ne peut pas observer tranquillement :
    /// il disparaît dès qu'on éloigne le curseur pour regarder le résultat.
    static var forcedPhase: NotchState.Phase? {
        switch ProcessInfo.processInfo.environment["LEDGENOTCH_FORCE_PHASE"] {
        case "peek": return .peek
        case "open": return .open
        case "closed": return .closed
        default: return nil
        }
    }

    /// `LEDGENOTCH_FORCE_PANEL=claude` choisit l'onglet affiché au lancement.
    static var forcedPanel: NotchState.Panel? {
        switch ProcessInfo.processInfo.environment["LEDGENOTCH_FORCE_PANEL"] {
        case "claude": return .claude
        case "weather": return .weather
        case "translate": return .translate
        case "deepwork": return .deepWork
        case "home": return .home
        default: return nil
        }
    }

    /// `LEDGENOTCH_SAMPLE_SPEECH="Bonjour"` remplit la transcription au
    /// lancement, pour éprouver la traduction sans parler dans le micro.
    static var sampleSpeech: String? {
        ProcessInfo.processInfo.environment["LEDGENOTCH_SAMPLE_SPEECH"]
    }

    /// `LEDGENOTCH_DEEPWORK=1` démarre une séance au lancement, pour observer
    /// le décompte sur l'encoche repliée sans attendre.
    static var startDeepWork: Bool {
        ProcessInfo.processInfo.environment["LEDGENOTCH_DEEPWORK"] == "1"
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
