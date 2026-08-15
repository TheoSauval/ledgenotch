import Combine
import Foundation

/// Une séance de travail concentré : un décompte, et rien d'autre.
@MainActor
final class DeepWorkTimer: ObservableObject {
    enum State: Equatable {
        case idle
        case running
        case paused
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var remaining: TimeInterval = 0
    @Published var duration: TimeInterval = 25 * 60
    @Published private(set) var completedToday = 0

    /// Émis à la fin d'une séance, pour que l'encoche se manifeste.
    let finished = PassthroughSubject<Void, Never>()

    static let presets: [TimeInterval] = [15 * 60, 25 * 60, 50 * 60, 90 * 60]

    private var timer: Timer?
    private var deadline: Date?
    private let defaults = UserDefaults.standard

    private enum Key {
        static let count = "deepWorkCompleted"
        static let day = "deepWorkDay"
        static let duration = "deepWorkDuration"
    }

    init() {
        let saved = defaults.double(forKey: Key.duration)
        if saved > 0 { duration = saved }
        remaining = duration
        loadCount()
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return 1 - (remaining / duration)
    }

    var isActive: Bool { state != .idle }

    /// `24:59` plutôt que `25:00` : afficher la durée pleine une seconde entière
    /// donne l'impression que le décompte n'a pas démarré.
    var clock: String {
        let total = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    // MARK: - Commandes

    func start() {
        guard state != .running else { return }

        if state == .idle { remaining = duration }
        deadline = Date().addingTimeInterval(remaining)
        state = .running
        schedule()
    }

    func pause() {
        guard state == .running else { return }
        invalidate()
        state = .paused
    }

    func toggle() {
        state == .running ? pause() : start()
    }

    func reset() {
        invalidate()
        state = .idle
        remaining = duration
    }

    func choose(_ value: TimeInterval) {
        duration = value
        defaults.set(value, forKey: Key.duration)
        if state == .idle { remaining = value }
    }

    // MARK: - Détail

    private func schedule() {
        invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        // Sans ce mode, le décompte se fige pendant qu'un menu est ouvert.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    /// Le temps restant se recalcule depuis une échéance plutôt que de se
    /// décrémenter : un Mac mis en veille arrêterait le minuteur, et la séance
    /// se poursuivrait comme si de rien n'était au réveil.
    private func tick() {
        guard let deadline else { return }
        remaining = max(0, deadline.timeIntervalSinceNow)
        guard remaining <= 0 else { return }
        complete()
    }

    private func complete() {
        invalidate()
        state = .idle
        remaining = duration
        recordCompletion()
        finished.send()
    }

    private func invalidate() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Compte du jour

    private func loadCount() {
        let today = Self.dayStamp()
        guard defaults.string(forKey: Key.day) == today else {
            completedToday = 0
            return
        }
        completedToday = defaults.integer(forKey: Key.count)
    }

    private func recordCompletion() {
        let today = Self.dayStamp()
        // Le compte repart à zéro chaque jour : c'est une jauge du jour, pas un
        // total qu'on regarderait grossir indéfiniment.
        if defaults.string(forKey: Key.day) != today {
            completedToday = 0
            defaults.set(today, forKey: Key.day)
        }
        completedToday += 1
        defaults.set(completedToday, forKey: Key.count)
    }

    private static func dayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}
