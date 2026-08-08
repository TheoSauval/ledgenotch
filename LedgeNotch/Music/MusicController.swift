import AppKit
import Combine

/// Suit ce qui joue sur la source choisie, et pilote la lecture.
///
/// Une seule source à la fois, celle que l'utilisateur a désignée. Interroger
/// les trois en permanence enverrait des événements Apple à des apps dont il ne
/// veut rien, et obligerait à départager deux lecteurs qui jouent en même temps.
@MainActor
final class MusicController: ObservableObject {
    @Published private(set) var track: MusicTrack?
    @Published private(set) var artwork: NSImage?

    /// Faux dès que l'utilisateur a refusé le contrôle du lecteur dans
    /// Confidentialité et sécurité. On cesse alors d'insister et on l'explique.
    @Published private(set) var isAuthorised = true

    /// Vrai quand le navigateur refuse d'exécuter du JavaScript : on sait alors
    /// afficher la vidéo, mais pas la commander.
    @Published private(set) var browserBlocksJavaScript = false

    /// Le navigateur où la vidéo a été trouvée, pour lui adresser les commandes.
    @Published private(set) var youTubeBrowser: Browser?

    private let preferences = Preferences.shared
    private let interval: TimeInterval = 3

    private var timer: Timer?
    private var artworkIdentity: String?
    private var cancellables = Set<AnyCancellable>()

    var source: MusicApp? { preferences.musicSource }
    var isPlaying: Bool { track?.isPlaying == true }

    func start() {
        refresh()

        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        // Sans ce mode, le sondage se fige pendant qu'un menu est ouvert.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        preferences.$musicSource
            .removeDuplicates()
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.reset()
                    self?.refresh()
                }
            }
            .store(in: &cancellables)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        cancellables.removeAll()
    }

    func choose(_ source: MusicApp?) {
        preferences.musicSource = source
    }

    private func reset() {
        track = nil
        artwork = nil
        artworkIdentity = nil
        browserBlocksJavaScript = false
        youTubeBrowser = nil
    }

    // MARK: - Commandes

    func playPause() { send(.playPause) }
    func next() { send(.next) }
    func previous() { send(.previous) }

    private func send(_ command: MusicScripts.Command) {
        guard let source else { return }

        if source == .youtube {
            guard let browser = youTubeBrowser else { return }
            YouTubeBridge.command(command, in: browser)
            scheduleFollowUp()
            return
        }

        guard let name = source.scriptingName else { return }
        AppleScriptRunner.run(MusicScripts.command(command, applicationNamed: name)) { [weak self] _ in
            self?.scheduleFollowUp()
        }
    }

    /// Le lecteur met un instant à appliquer la commande : interroger trop tôt
    /// renverrait l'état précédent et ferait clignoter l'affichage.
    private func scheduleFollowUp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    // MARK: - Sondage

    func refresh() {
        guard let source else {
            if track != nil { reset() }
            return
        }

        switch source {
        case .appleMusic, .spotify:
            refreshApplication(source)
        case .youtube:
            refreshYouTube()
        }
    }

    private func refreshApplication(_ source: MusicApp) {
        guard source.isAvailable, let name = source.scriptingName else {
            adopt(nil)
            return
        }

        AppleScriptRunner.run(MusicScripts.nowPlaying(applicationNamed: name)) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let descriptor):
                self.isAuthorised = true
                self.adopt(Self.parse(descriptor.stringValue, source: source))
            case .failure(.notAuthorized):
                self.isAuthorised = false
                self.adopt(nil)
            case .failure:
                self.adopt(nil)
            }
        }
    }

    private func refreshYouTube() {
        YouTubeBridge.findTab { [weak self] tab in
            guard let self else { return }
            guard let tab else {
                self.youTubeBrowser = nil
                self.adopt(nil)
                return
            }

            self.youTubeBrowser = tab.browser
            YouTubeBridge.playbackState(in: tab.browser) { playing in
                // Sans JavaScript on ne sait pas si la vidéo tourne. On la
                // suppose en lecture : c'est le cas le plus fréquent quand un
                // onglet YouTube est ouvert, et l'inverse afficherait en
                // permanence un bouton lecture trompeur.
                self.browserBlocksJavaScript = (playing == nil)
                self.adopt(
                    MusicTrack(
                        source: .youtube,
                        title: tab.title,
                        artist: tab.browser.scriptingName,
                        album: "",
                        isPlaying: playing ?? true
                    ),
                    videoID: tab.videoID
                )
            }
        }
    }

    private func adopt(_ new: MusicTrack?, videoID: String? = nil) {
        guard track != new else { return }
        track = new

        guard let new else {
            artwork = nil
            artworkIdentity = nil
            return
        }
        if artworkIdentity != new.identity {
            loadArtwork(for: new, videoID: videoID)
        }
    }

    private func loadArtwork(for track: MusicTrack, videoID: String?) {
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

        case .youtube:
            guard let videoID, let url = YouTubeBridge.thumbnailURL(for: videoID) else { return }
            download(url, for: track)
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
