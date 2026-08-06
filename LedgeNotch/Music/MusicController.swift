import AppKit
import Combine

/// Suit ce qui joue, et pilote la lecture.
@MainActor
final class MusicController: ObservableObject {
    @Published private(set) var track: MusicTrack?
    @Published private(set) var artwork: NSImage?

    /// Faux dès que l'utilisateur a refusé le contrôle du lecteur dans
    /// Confidentialité et sécurité. On cesse alors d'insister et on l'explique.
    @Published private(set) var isAuthorised = true

    /// Assez fréquent pour suivre un changement de morceau, assez espacé pour
    /// qu'un événement Apple toutes les trois secondes ne pèse pas.
    private let interval: TimeInterval = 3

    private var timer: Timer?
    private var artworkIdentity: String?

    var isPlaying: Bool { track?.isPlaying == true }

    func start() {
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // Sans ce mode, le sondage se fige pendant qu'un menu est ouvert.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Commandes

    func playPause() { send(.playPause) }
    func next() { send(.next) }
    func previous() { send(.previous) }

    private func send(_ command: MusicScripts.Command) {
        guard let app = track?.source else { return }
        AppleScriptRunner.run(MusicScripts.command(command, for: app)) { [weak self] _ in
            // Le lecteur met un instant à appliquer la commande : interroger
            // trop tôt renverrait l'état précédent et ferait clignoter l'affichage.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                MainActor.assumeIsolated { self?.refresh() }
            }
        }
    }

    // MARK: - Sondage

    func refresh() {
        let apps = MusicApp.running
        guard !apps.isEmpty else {
            adopt([:])
            return
        }

        var results: [MusicApp: MusicTrack] = [:]
        var pending = apps.count

        for app in apps {
            AppleScriptRunner.run(MusicScripts.nowPlaying(for: app)) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success(let descriptor):
                    self.isAuthorised = true
                    if let parsed = Self.parse(descriptor.stringValue, source: app) {
                        results[app] = parsed
                    }
                case .failure(.notAuthorized):
                    self.isAuthorised = false
                case .failure:
                    break
                }

                pending -= 1
                if pending == 0 { self.adopt(results) }
            }
        }
    }

    /// Entre deux lecteurs ouverts, celui qui joue l'emporte : c'est celui que
    /// l'utilisateur écoute, même si l'autre garde un morceau en pause.
    private func adopt(_ results: [MusicApp: MusicTrack]) {
        let chosen = results.values.first(where: \.isPlaying)
            ?? results.values.sorted { $0.source.rawValue < $1.source.rawValue }.first

        guard track != chosen else { return }
        track = chosen

        guard let chosen else {
            artwork = nil
            artworkIdentity = nil
            return
        }
        if artworkIdentity != chosen.identity {
            loadArtwork(for: chosen)
        }
    }

    private func loadArtwork(for track: MusicTrack) {
        artworkIdentity = track.identity
        artwork = nil

        switch track.source {
        case .appleMusic:
            AppleScriptRunner.run(MusicScripts.appleMusicArtwork) { [weak self] result in
                // Le morceau a pu changer entre la demande et la réponse : sans
                // ce contrôle, on collerait la pochette du précédent.
                guard let self, self.artworkIdentity == track.identity else { return }
                guard case .success(let descriptor) = result, !descriptor.data.isEmpty else { return }
                self.artwork = NSImage(data: descriptor.data)
            }

        case .spotify:
            AppleScriptRunner.run(MusicScripts.spotifyArtworkURL) { [weak self] result in
                guard let self, self.artworkIdentity == track.identity else { return }
                guard
                    case .success(let descriptor) = result,
                    let address = descriptor.stringValue,
                    let url = URL(string: address),
                    url.scheme == "https"
                else { return }
                self.download(url, for: track)
            }
        }
    }

    private func download(_ url: URL, for track: MusicTrack) {
        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self, self.artworkIdentity == track.identity else { return }
                    self.artwork = image
                }
            }
        }.resume()
    }

    private static func parse(_ raw: String?, source: MusicApp) -> MusicTrack? {
        guard let raw, !raw.isEmpty else { return nil }
        let parts = raw.components(separatedBy: MusicScripts.separator)
        guard parts.count >= 4 else { return nil }

        let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return nil }

        return MusicTrack(
            source: source,
            title: title,
            artist: parts[1].trimmingCharacters(in: .whitespacesAndNewlines),
            album: parts[2].trimmingCharacters(in: .whitespacesAndNewlines),
            isPlaying: parts[3].lowercased().contains("playing")
        )
    }
}
