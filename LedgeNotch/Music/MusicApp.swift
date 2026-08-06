import AppKit

/// Les lecteurs pilotables par AppleScript.
///
/// AppleScript plutôt que `MediaRemote` : Apple a verrouillé ce framework privé
/// depuis macOS 15.4, et les contournements existants cassent à chaque mise à
/// jour du système. On perd l'audio du navigateur et des lecteurs tiers, on
/// gagne quelque chose qui fonctionne encore dans six mois.
enum MusicApp: String, CaseIterable, Identifiable {
    case appleMusic
    case spotify

    var id: String { rawValue }

    var bundleIdentifier: String {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        }
    }

    /// Le nom auquel AppleScript répond, qui n'est pas toujours celui de l'app.
    var scriptingName: String {
        switch self {
        case .appleMusic: return "Music"
        case .spotify: return "Spotify"
        }
    }

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        }
    }

    /// Interroger une app à l'arrêt la **lance**. On ne parle donc qu'à celles
    /// déjà ouvertes, sinon LedgeNotch démarrerait Spotify tout seul au réveil.
    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    static var running: [MusicApp] {
        allCases.filter(\.isRunning)
    }
}
