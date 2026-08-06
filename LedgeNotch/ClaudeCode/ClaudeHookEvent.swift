import Foundation

/// Un événement émis par un hook de Claude Code.
///
/// Les hooks reçoivent leur charge utile en JSON sur l'entrée standard ; on se
/// contente de la réécrire telle quelle dans le journal. Tous les champs hors
/// `session_id` et `hook_event_name` dépendent de l'événement, d'où les optionnels.
struct ClaudeHookEvent: Decodable {
    let sessionId: String
    let hookEventName: String
    let cwd: String?
    let notificationType: String?
    let message: String?
    let lastAssistantMessage: String?
    let userInput: String?
    let endReason: String?

    enum Name {
        static let sessionStart = "SessionStart"
        static let sessionEnd = "SessionEnd"
        static let userPromptSubmit = "UserPromptSubmit"
        static let notification = "Notification"
        static let stop = "Stop"
    }

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    static func decode(line: String) -> ClaudeHookEvent? {
        guard let data = line.data(using: .utf8), !data.isEmpty else { return nil }
        return try? decoder.decode(ClaudeHookEvent.self, from: data)
    }
}
