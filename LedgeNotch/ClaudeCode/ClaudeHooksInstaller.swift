import Foundation

/// Installe et retire les hooks LedgeNotch dans `~/.claude/settings.json`.
///
/// Ce fichier appartient à l'utilisateur et contient bien d'autres réglages : on
/// le relit à chaque fois, on modifie uniquement les entrées reconnaissables à
/// leur commande, et on sauvegarde l'original avant d'écrire.
enum ClaudeHooksInstaller {
    static let settingsURL = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/settings.json")

    /// Les événements suivis, et ce qu'ils apprennent.
    static let events = [
        ClaudeHookEvent.Name.sessionStart,
        ClaudeHookEvent.Name.userPromptSubmit,
        ClaudeHookEvent.Name.notification,
        ClaudeHookEvent.Name.stop,
        ClaudeHookEvent.Name.sessionEnd,
    ]

    /// Marqueur permettant de reconnaître nos entrées parmi celles de l'utilisateur.
    private static let marker = ".ledgenotch"

    enum InstallError: LocalizedError {
        case unreadable
        case malformed
        case unwritable

        var errorDescription: String? {
            switch self {
            case .unreadable: return "Impossible de lire ~/.claude/settings.json."
            case .malformed: return "~/.claude/settings.json n'est pas un JSON valide."
            case .unwritable: return "Impossible d'écrire dans ~/.claude/settings.json."
            }
        }
    }

    static var isInstalled: Bool {
        guard let hooks = loadSettings()?["hooks"] as? [String: Any] else { return false }
        return events.allSatisfy { event in
            guard let groups = hooks[event] as? [[String: Any]] else { return false }
            return groups.contains { group in
                (group["hooks"] as? [[String: Any]])?.contains { handler in
                    (handler["command"] as? String)?.contains(marker) == true
                } == true
            }
        }
    }

    static func install() throws {
        var settings = try requireSettings()
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        for event in events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            groups.removeAll(where: { isOurs($0) })
            groups.append([
                "hooks": [[
                    "type": "command",
                    "command": ClaudeEventLog.hookCommand,
                ]],
            ])
            hooks[event] = groups
        }

        settings["hooks"] = hooks
        try write(settings)
    }

    static func uninstall() throws {
        var settings = try requireSettings()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for event in events {
            guard var groups = hooks[event] as? [[String: Any]] else { continue }
            groups.removeAll(where: { isOurs($0) })
            // Une clé laissée avec un tableau vide n'apporte rien : autant rendre
            // le fichier tel qu'on l'a trouvé.
            if groups.isEmpty { hooks[event] = nil } else { hooks[event] = groups }
        }

        if hooks.isEmpty { settings["hooks"] = nil } else { settings["hooks"] = hooks }
        try write(settings)
    }

    // MARK: - Détail

    private static func isOurs(_ group: [String: Any]) -> Bool {
        (group["hooks"] as? [[String: Any]])?.allSatisfy { handler in
            (handler["command"] as? String)?.contains(marker) == true
        } ?? false
    }

    private static func loadSettings() -> [String: Any]? {
        guard let data = try? Data(contentsOf: settingsURL) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    /// Un fichier absent est normal — il suffit de le créer. Un fichier présent
    /// mais illisible ne l'est pas : mieux vaut s'arrêter que l'écraser.
    private static func requireSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        guard let data = try? Data(contentsOf: settingsURL) else { throw InstallError.unreadable }
        guard data.isEmpty == false else { return [:] }
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let settings = object as? [String: Any]
        else { throw InstallError.malformed }
        return settings
    }

    private static func write(_ settings: [String: Any]) throws {
        backup()
        guard let data = try? JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) else { throw InstallError.unwritable }

        try? FileManager.default.createDirectory(
            at: settingsURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        do {
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            throw InstallError.unwritable
        }
    }

    private static func backup() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        let backupURL = settingsURL.appendingPathExtension("ledgenotch-backup")
        try? FileManager.default.removeItem(at: backupURL)
        try? FileManager.default.copyItem(at: settingsURL, to: backupURL)
    }
}
