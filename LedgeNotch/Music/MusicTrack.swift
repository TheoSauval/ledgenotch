import AppKit

struct MusicTrack: Equatable {
    let source: MusicApp
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool

    /// Identifie un morceau indépendamment de l'état de lecture, pour éviter de
    /// recharger la pochette à chaque sondage.
    var identity: String { "\(source.rawValue)|\(title)|\(artist)|\(album)" }

    var subtitle: String {
        [artist, album]
            .filter { !$0.isEmpty }
            .joined(separator: " — ")
    }
}
