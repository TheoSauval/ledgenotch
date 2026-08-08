import AppKit

/// Les navigateurs pilotables par AppleScript.
///
/// Toute la famille Chromium partage le même vocabulaire — `title of tab`,
/// `execute … javascript` — là où Safari a le sien : `name of tab`,
/// `do JavaScript … in`.
enum Browser: String, CaseIterable {
    case chrome
    case arc
    case brave
    case edge
    case vivaldi
    case safari

    var scriptingName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .arc: return "Arc"
        case .brave: return "Brave Browser"
        case .edge: return "Microsoft Edge"
        case .vivaldi: return "Vivaldi"
        case .safari: return "Safari"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .arc: return "company.thebrowser.Browser"
        case .brave: return "com.brave.Browser"
        case .edge: return "com.microsoft.edgemac"
        case .vivaldi: return "com.vivaldi.Vivaldi"
        case .safari: return "com.apple.Safari"
        }
    }

    var isChromium: Bool { self != .safari }

    /// Le réglage à activer pour que le navigateur accepte d'exécuter du
    /// JavaScript venu d'une autre app. Il est masqué par défaut dans les deux.
    var javaScriptSettingPath: String {
        isChromium
            ? "Affichage → Développeur → Autoriser JavaScript depuis les Apple Events"
            : "Safari → Réglages → Avancé → Afficher les fonctionnalités pour développeurs web, puis Développement → Autoriser JavaScript depuis les Apple Events"
    }

    var isRunning: Bool {
        NSWorkspace.shared.runningApplications.contains {
            $0.bundleIdentifier == bundleIdentifier
        }
    }

    static var running: [Browser] {
        allCases.filter(\.isRunning)
    }
}
