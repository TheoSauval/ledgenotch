import Foundation

/// Ce que fait une session Claude Code à un instant donné.
enum ClaudeActivity: Int, Comparable {
    /// Rien en cours : la session existe mais attend un prochain tour.
    case idle = 0
    /// Vient de terminer. État transitoire, pour laisser le temps de le remarquer.
    case done = 1
    /// Un tour est en cours.
    case working = 2
    /// Bloquée sur une question ou une demande d'autorisation.
    case waiting = 3

    static func < (lhs: ClaudeActivity, rhs: ClaudeActivity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct ClaudeSession: Identifiable, Equatable {
    let id: String
    /// Nom du dossier de travail : c'est ainsi qu'on reconnaît un projet d'un coup d'œil.
    var project: String
    var activity: ClaudeActivity
    /// Précision affichée sous le nom du projet, quand il y en a une.
    var detail: String?
    var updatedAt: Date

    init(id: String, cwd: String?, activity: ClaudeActivity = .idle, detail: String? = nil) {
        self.id = id
        self.project = ClaudeSession.projectName(from: cwd)
        self.activity = activity
        self.detail = detail
        self.updatedAt = Date()
    }

    static func projectName(from cwd: String?) -> String {
        guard let cwd, !cwd.isEmpty else { return "Session" }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
}
