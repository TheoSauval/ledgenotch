import AppKit
import SwiftUI

/// Les sources de lecture proposées dans l'encoche.
///
/// AppleScript plutôt que `MediaRemote` : Apple a verrouillé ce framework privé
/// depuis macOS 15.4, et les contournements existants cassent à chaque mise à
/// jour du système. On gagne quelque chose qui fonctionne encore dans six mois.
///
/// YouTube n'est pas une app mais un onglet de navigateur, et se traite donc à
/// part — voir `YouTubeBridge`.
enum MusicApp: String, CaseIterable, Identifiable {
    case appleMusic
    case spotify
    case youtube

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .youtube: return "YouTube"
        }
    }

    var symbolName: String {
        switch self {
        case .appleMusic: return "music.note"
        case .spotify: return "waveform"
        case .youtube: return "play.rectangle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .appleMusic: return Color(red: 0.98, green: 0.23, blue: 0.34)
        case .spotify: return Color(red: 0.11, green: 0.84, blue: 0.38)
        case .youtube: return Color(red: 1.0, green: 0.2, blue: 0.2)
        }
    }

    /// Le nom auquel AppleScript répond, quand la source est une vraie app.
    var scriptingName: String? {
        switch self {
        case .appleMusic: return "Music"
        case .spotify: return "Spotify"
        case .youtube: return nil
        }
    }

    var bundleIdentifier: String? {
        switch self {
        case .appleMusic: return "com.apple.Music"
        case .spotify: return "com.spotify.client"
        case .youtube: return nil
        }
    }

    /// Interroger une app à l'arrêt la **lance**. On ne parle donc qu'à celles
    /// déjà ouvertes, sinon LedgeNotch démarrerait Spotify tout seul au réveil.
    var isAvailable: Bool {
        switch self {
        case .appleMusic, .spotify:
            guard let bundleIdentifier else { return false }
            return NSWorkspace.shared.runningApplications.contains {
                $0.bundleIdentifier == bundleIdentifier
            }
        case .youtube:
            return !Browser.running.isEmpty
        }
    }

    static var available: [MusicApp] {
        allCases.filter(\.isAvailable)
    }
}
