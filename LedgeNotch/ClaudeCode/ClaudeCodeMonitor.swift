import Combine
import Foundation

/// Tient à jour l'état des sessions Claude Code, à partir du journal des hooks.
@MainActor
final class ClaudeCodeMonitor: ObservableObject {
    @Published private(set) var sessions: [ClaudeSession] = []

    /// Émis quand une session réclame l'attention : elle se bloque sur une
    /// question, ou elle vient de terminer. C'est ce que le contrôleur guette
    /// pour faire dépasser l'encoche.
    let attention = PassthroughSubject<ClaudeSession, Never>()

    private let log = ClaudeEventLog()
    private var storage: [String: ClaudeSession] = [:]
    private var doneTimers: [String: DispatchWorkItem] = [:]

    /// Durée pendant laquelle une session terminée reste signalée avant de
    /// retomber au repos.
    private let doneDuration: TimeInterval = 8

    /// Une session sans le moindre événement depuis ce délai est oubliée : un
    /// terminal fermé brutalement n'émet pas de `SessionEnd`.
    private let staleAfter: TimeInterval = 4 * 3600

    /// L'activité la plus notable, toutes sessions confondues.
    var overall: ClaudeActivity? {
        sessions.map(\.activity).filter { $0 != .idle }.max()
    }

    var isActive: Bool { overall != nil }

    func start() {
        log.start { [weak self] event in
            self?.apply(event)
        }
    }

    func stop() {
        log.stop()
        doneTimers.values.forEach { $0.cancel() }
        doneTimers.removeAll()
    }

    // MARK: - Application des événements

    private func apply(_ event: ClaudeHookEvent) {
        switch event.hookEventName {
        case ClaudeHookEvent.Name.sessionEnd:
            remove(event.sessionId)
            return

        case ClaudeHookEvent.Name.sessionStart:
            update(event, activity: .idle, detail: nil)

        case ClaudeHookEvent.Name.userPromptSubmit:
            update(event, activity: .working, detail: event.userInput.flatMap(Self.summarise))

        case ClaudeHookEvent.Name.notification:
            // `permission_prompt` et `idle_prompt` veulent tous deux dire « la
            // main est à l'utilisateur » ; les autres notifications sont
            // informatives et ne doivent pas bloquer l'affichage.
            let blocking = event.notificationType.map {
                $0 == "permission_prompt" || $0 == "idle_prompt"
            } ?? true
            guard blocking else { return }
            update(event, activity: .waiting, detail: event.message.flatMap(Self.summarise))

        case ClaudeHookEvent.Name.stop:
            update(
                event,
                activity: .done,
                detail: event.lastAssistantMessage.flatMap(Self.summarise)
            )
            scheduleReturnToIdle(event.sessionId)

        default:
            return
        }

        publish()

        if let session = storage[event.sessionId],
           session.activity == .waiting || session.activity == .done {
            attention.send(session)
        }
    }

    private func update(_ event: ClaudeHookEvent, activity: ClaudeActivity, detail: String?) {
        doneTimers[event.sessionId]?.cancel()
        doneTimers[event.sessionId] = nil

        var session = storage[event.sessionId]
            ?? ClaudeSession(id: event.sessionId, cwd: event.cwd)
        if let cwd = event.cwd {
            session.project = ClaudeSession.projectName(from: cwd)
        }
        session.activity = activity
        session.detail = detail
        session.updatedAt = Date()
        storage[event.sessionId] = session
    }

    private func scheduleReturnToIdle(_ id: String) {
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.doneTimers[id] = nil
                guard var session = self.storage[id], session.activity == .done else { return }
                session.activity = .idle
                session.detail = nil
                self.storage[id] = session
                self.publish()
            }
        }
        doneTimers[id] = work
        DispatchQueue.main.asyncAfter(deadline: .now() + doneDuration, execute: work)
    }

    private func remove(_ id: String) {
        doneTimers[id]?.cancel()
        doneTimers[id] = nil
        storage[id] = nil
        publish()
    }

    private func publish() {
        let cutoff = Date().addingTimeInterval(-staleAfter)
        storage = storage.filter { $0.value.updatedAt > cutoff }
        sessions = storage.values.sorted {
            ($0.activity, $0.updatedAt) > ($1.activity, $1.updatedAt)
        }
    }

    /// Réduit un message à une ligne courte : les vues de l'encoche n'ont pas
    /// la place d'afficher un paragraphe.
    private static func summarise(_ text: String) -> String? {
        let flat = text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !flat.isEmpty else { return nil }
        return flat.count > 70 ? String(flat.prefix(69)) + "…" : flat
    }
}
