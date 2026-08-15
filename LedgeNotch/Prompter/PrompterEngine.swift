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
    @Published private(set) var isAutoScrolling = false
    @Published private(set) var isFollowingVoice = false

    /// Position dans le texte, en rang de mot — mais fractionnaire.
    ///
    /// Un entier ferait sauter le texte d'une ligne à l'autre. En avançant par
    /// fractions de mot, le défilement devient continu et la vue n'a plus qu'à
    /// interpoler entre deux lignes.
    @Published private(set) var position: Double = 0

    private var cursor: Int { Int(position) }
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
        return min(1, position / Double(words.count))
    }

    /// La ligne en cours, et l'avancement à l'intérieur de celle-ci.
    var currentChunk: Int {
        chunks.lastIndex { Double($0.firstWord) <= position } ?? 0
    }

    var fractionWithinChunk: Double {
        guard currentChunk < chunks.count else { return 0 }
        let chunk = chunks[currentChunk]
        let next = currentChunk + 1 < chunks.count
            ? chunks[currentChunk + 1].firstWord
            : words.count
        let span = Double(next - chunk.firstWord)
        guard span > 0 else { return 0 }
        return min(1, max(0, (position - Double(chunk.firstWord)) / span))
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

    /// Longueur maximale d'une ligne, en caractères.
    ///
    /// Le découpage se fait sur la longueur et non sur un nombre de mots : la
    /// vue calcule le défilement en supposant que chaque ligne en occupe
    /// exactement une, et une ligne qui déborderait décalerait tout le reste.
    /// Quarante-cinq caractères tiennent même à la plus grande taille de police.
    private static let lineLength = 45

    private static func split(_ script: String) -> [Chunk] {
        var result: [Chunk] = []
        var wordCount = 0

        let sentences = script
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        for sentence in sentences {
            var line: [String] = []
            var length = 0

            for word in sentence.split(separator: " ").map(String.init) {
                if !line.isEmpty, length + word.count + 1 > lineLength {
                    result.append(
                        Chunk(id: result.count, text: line.joined(separator: " "), firstWord: wordCount)
                    )
                    wordCount += line.count
                    line = []
                    length = 0
                }
                line.append(word)
                length += word.count + 1
            }

            if !line.isEmpty {
                result.append(
                    Chunk(id: result.count, text: line.joined(separator: " "), firstWord: wordCount)
                )
                wordCount += line.count
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
        position = 0
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
                position = Double(found + length)
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

        // Un battement toutes les cent millisecondes, et la vue interpole entre
        // deux : dix rafraîchissements par seconde suffisent à un mouvement
        // continu, là où soixante feraient tourner l'interface pour rien.
        let timer = Timer.scheduledTimer(withTimeInterval: Self.tick, repeats: true) { [weak self] _ in
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

    static let tick: TimeInterval = 0.1

    private func step() {
        guard position < Double(words.count) else {
            stopAutoScroll()
            return
        }
        position += preferences.prompterSpeed / 60 * Self.tick
    }
}
