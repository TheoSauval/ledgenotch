import Foundation

/// Les scripts AppleScript, rassemblés ici pour ne pas les éparpiller dans la
/// logique.
enum MusicScripts {
    /// Séparateur improbable dans un titre de morceau, contrairement à un tiret
    /// ou une barre verticale.
    static let separator = "\u{1F}"

    /// Renvoie `titre␟artiste␟album␟état`, ou une chaîne vide.
    ///
    /// Le `try` est indispensable : `current track` lève une erreur dès que la
    /// file d'attente est vide, ce qui est le cas ordinaire d'une app ouverte
    /// mais inutilisée.
    static func nowPlaying(for app: MusicApp) -> String {
        """
        tell application "\(app.scriptingName)"
            try
                if player state is stopped then return ""
                set sep to (ASCII character 31)
                set theTitle to name of current track
                set theArtist to artist of current track
                set theAlbum to album of current track
                set theState to (player state as text)
                return theTitle & sep & theArtist & sep & theAlbum & sep & theState
            on error
                return ""
            end try
        end tell
        """
    }

    /// Spotify ne donne qu'une adresse : la pochette se récupère ensuite sur son
    /// réseau de diffusion. C'est le seul appel réseau de toute l'app.
    static let spotifyArtworkURL = """
    tell application "Spotify"
        try
            if player state is stopped then return ""
            return artwork url of current track
        on error
            return ""
        end try
    end tell
    """

    /// Apple Music expose directement les octets de la pochette, sans réseau.
    static let appleMusicArtwork = """
    tell application "Music"
        try
            if player state is stopped then return missing value
            return raw data of artwork 1 of current track
        on error
            return missing value
        end try
    end tell
    """

    enum Command: String {
        case playPause = "playpause"
        case next = "next track"
        case previous = "previous track"
    }

    static func command(_ command: Command, for app: MusicApp) -> String {
        """
        tell application "\(app.scriptingName)"
            try
                \(command.rawValue)
            end try
        end tell
        """
    }
}
