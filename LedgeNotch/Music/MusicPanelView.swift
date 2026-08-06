import SwiftUI

/// Le contenu de l'encoche ouverte quand on choisit l'onglet musique.
struct MusicPanelView: View {
    @ObservedObject var music: MusicController

    var body: some View {
        if let track = music.track {
            player(track)
        } else {
            empty
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: music.isAuthorised ? "music.note" : "lock.slash")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.35))

            Text(music.isAuthorised ? "Rien en lecture" : "Contrôle refusé")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            Text(music.isAuthorised
                 ? "Ouvre Apple Music ou Spotify."
                 : "Autorise LedgeNotch dans Réglages Système → Confidentialité et sécurité → Automatisation.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
    }

    private func player(_ track: MusicTrack) -> some View {
        // Alignée en haut et contrainte à la hauteur de la pochette, la colonne
        // de texte garde ses commandes au niveau du bas de l'image. Sans ça, la
        // pochette flottait au milieu d'une colonne plus haute qu'elle.
        HStack(alignment: .top, spacing: 14) {
            artwork

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(track.subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)

                Text(track.source.displayName)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 1)

                Spacer(minLength: 6)

                transport(isPlaying: track.isPlaying)
            }
            .frame(height: 96, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
    }

    private var artwork: some View {
        Group {
            if let image = music.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                // Spotify ne donne qu'une URL de pochette, qu'il faudrait aller
                // chercher sur le réseau : on affiche un cadre plutôt que rien.
                ZStack {
                    Color.white.opacity(0.07)
                    Image(systemName: "music.note")
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func transport(isPlaying: Bool) -> some View {
        HStack(spacing: 16) {
            TransportButton(system: "backward.fill", size: 13, action: music.previous)
            TransportButton(
                system: isPlaying ? "pause.fill" : "play.fill",
                size: 18,
                action: music.playPause
            )
            TransportButton(system: "forward.fill", size: 13, action: music.next)
        }
    }
}

private struct TransportButton: View {
    let system: String
    let size: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white.opacity(isHovering ? 1 : 0.7))
                .frame(width: size + 12, height: size + 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}
