import Combine
import Foundation

/// Le texte du prompteur, découpé et suivi au fil de la lecture.
///
/// Deux façons d'avancer : au son de la voix, ou à vitesse constante. La
/// première demande de recaler en permanence ce qui est dit sur ce qui est
/// écrit ; la seconde sert de repli quand le micro n'est pas une option.
@MainActor
final class PrompterEngine: ObservableObject {
    struct Chunk: Identifiable, Equatable {
        let id: Int
        let text: String
        /// Rang du premier mot du morceau dans le texte entier.
        let firstWord: Int
    }

    @Published private(set) var chunks: [Chunk] = []
    @Published private(set) var currentChunk = 0
    @Published private(set) var isAutoScrolling = false
    @Published private(set) var isFollowingVoice = false

    /// Rang du prochain mot attendu.
    private var cursor = 0
    private var words: [String] = []
    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let preferences = Preferences.shared

    /// Au-delà de cette avance, on considère que le lecteur n'en est pas là :
    /// sans limite, un mot courant comme « le » ferait sauter à l'autre bout.
    private let searchWindow = 45

    var isEmpty: Bool { chunks.isEmpty }
    var progress: Double {
        guard !words.isEmpty else { return 0 }
        return Double(cursor) / Double(words.count)
    }

    init() {
        load(preferences.prompterScript)
        preferences.$prompterScript
            .removeDuplicates()
            .sink { [weak self] script in
                MainActor.assumeIsolated { self?.load(script) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Texte

    private func load(_ script: String) {
        words = Self.normalise(script)
        chunks = Self.split(script)
        rewind()
    }

    /// Découpe en phrases, puis en tranches d'une douzaine de mots : une phrase
    /// de quarante mots occuperait tout l'écran et ne dirait plus où l'on en est.
    private static func split(_ script: String) -> [Chunk] {
        var result: [Chunk] = []
        var wordCount = 0

        let sentences = script
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for sentence in sentences {
            let parts = sentence.split(separator: " ").map(String.init)
            for slice in stride(from: 0, to: parts.count, by: 12) {
                let piece = parts[slice..<min(slice + 12, parts.count)]
                result.append(
                    Chunk(id: result.count, text: piece.joined(separator: " "), firstWord: wordCount)
                )
                wordCount += piece.count
            }
        }
        return result
    }

    /// Minuscules, sans accents ni ponctuation : la reconnaissance vocale écrit
    /// « ça » quand le texte dit « Ca », et « c'est » quand il dit « c'est, ».
    private static func normalise(_ text: String) -> [String] {
        text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }

    // MARK: - Position

    func rewind() {
        cursor = 0
        currentChunk = 0
    }

    private func syncChunk() {
        guard let index = chunks.lastIndex(where: { $0.firstWord <= cursor }) else { return }
        currentChunk = index
    }

    // MARK: - Suivi de la voix

    func followVoice(_ following: Bool) {
        isFollowingVoice = following
        if following { stopAutoScroll() }
    }

    /// Recale la position sur ce qui vient d'être prononcé.
    ///
    /// On cherche les derniers mots entendus devant le curseur, du plus long
    /// enchaînement au plus court : trois mots consécutifs ne se répètent
    /// pratiquement jamais, là où un seul mot se retrouve partout.
    func hear(_ transcript: String) {
        guard isFollowingVoice, !words.isEmpty else { return }

        let spoken = Self.normalise(transcript)
        guard !spoken.isEmpty else { return }

        let end = min(words.count, cursor + searchWindow)
        guard cursor < end else { return }

        for length in stride(from: min(3, spoken.count), through: 1, by: -1) {
            let tail = Array(spoken.suffix(length))
            var found: Int?
            var index = cursor
            while index + length <= end {
                if Array(words[index..<(index + length)]) == tail { found = index }
                index += 1
            }
            if let found {
                cursor = found + length
                syncChunk()
                return
            }
        }
    }

    // MARK: - Défilement automatique

    func toggleAutoScroll() {
        isAutoScrolling ? stopAutoScroll() : startAutoScroll()
    }

    private func startAutoScroll() {
        guard !words.isEmpty else { return }
        isFollowingVoice = false
        isAutoScrolling = true

        let interval = 60.0 / max(preferences.prompterSpeed, 30)
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.step() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stopAutoScroll() {
        timer?.invalidate()
        timer = nil
        isAutoScrolling = false
    }

    private func step() {
        guard cursor < words.count else {
            stopAutoScroll()
            return
        }
        cursor += 1
        syncChunk()
    }
}
