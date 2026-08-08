import SwiftUI

/// Le contenu de l'encoche ouverte quand on choisit l'onglet musique.
///
/// Tant qu'aucune source n'est retenue, on affiche le sélecteur : LedgeNotch ne
/// devine pas où l'utilisateur écoute, et interroger les trois en permanence
/// enverrait des événements Apple à des apps dont il ne veut rien.
struct MusicPanelView: View {
    @ObservedObject var music: MusicController

    var body: some View {
        if music.source == nil {
            MusicSourcePicker(music: music)
        } else if let track = music.track {
            player(track)
        } else {
            waiting
        }
    }

    // MARK: - En attente

    private var waiting: some View {
        VStack(spacing: 7) {
            Image(systemName: music.isAuthorised ? "music.note" : "lock.slash")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.35))

            Text(music.isAuthorised ? "Rien en lecture" : "Contrôle refusé")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            Text(waitingHint)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 34)

            changeSourceButton
                .padding(.top, 2)
        }
    }

    private var waitingHint: String {
        guard music.isAuthorised else {
            return "Autorise LedgeNotch dans Réglages Système → Confidentialité et sécurité → Automatisation."
        }
        switch music.source {
        case .youtube: return "Ouvre une vidéo YouTube dans ton navigateur."
        case .appleMusic: return "Lance Apple Music et mets un morceau."
        case .spotify: return "Lance Spotify et mets un morceau."
        case .none: return ""
        }
    }

    // MARK: - Lecteur

    private func player(_ track: MusicTrack) -> some View {
        HStack(alignment: .top, spacing: 14) {
            artwork(for: track)

            VStack(alignment: .leading, spacing: 3) {
                Text(track.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if !track.subtitle.isEmpty {
                    Text(track.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                changeSourceButton.padding(.top, 1)

                Spacer(minLength: 6)

                if music.source == .youtube, music.browserBlocksJavaScript {
                    javaScriptHint
                } else {
                    transport(isPlaying: track.isPlaying)
                }
            }
            .frame(height: 96, alignment: .topLeading)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
    }

    private func artwork(for track: MusicTrack) -> some View {
        Group {
            if let image = music.artwork {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.07)
                    Image(systemName: track.source.symbolName)
                        .font(.system(size: 22, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// Le nom de la source sert aussi de retour au sélecteur : dans 190 points
    /// de haut, un bouton dédié coûterait une ligne qu'on n'a pas.
    private var changeSourceButton: some View {
        Button {
            music.choose(nil)
        } label: {
            HStack(spacing: 3) {
                Text(music.source?.displayName ?? "Source")
                Image(systemName: "chevron.down")
                    .font(.system(size: 7, weight: .bold))
            }
            .font(.system(size: 9, weight: .medium))
            .foregroundStyle(.white.opacity(0.35))
        }
        .buttonStyle(.plain)
        .help("Changer de source")
    }

    private var javaScriptHint: some View {
        Text("Commandes indisponibles : autorise « JavaScript depuis les Apple Events » dans ton navigateur.")
            .font(.system(size: 9))
            .foregroundStyle(.orange.opacity(0.75))
            .lineLimit(3)
            .fixedSize(horizontal: false, vertical: true)
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

/// Le choix de la source, première chose affichée dans l'onglet musique.
private struct MusicSourcePicker: View {
    @ObservedObject var music: MusicController

    var body: some View {
        VStack(spacing: 12) {
            Text("Où écoutes-tu ?")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 10) {
                ForEach(MusicApp.allCases) { source in
                    SourceTile(source: source) { music.choose(source) }
                }
            }
        }
    }
}

private struct SourceTile: View {
    let source: MusicApp
    let action: () -> Void

    @State private var isHovering = false

    /// Griser une source fermée plutôt que la masquer : l'utilisateur comprend
    /// alors qu'il faut la lancer, au lieu de chercher une option disparue.
    private var isAvailable: Bool { source.isAvailable }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: source.symbolName)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isAvailable ? source.tint : .white.opacity(0.25))

                Text(source.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(isAvailable ? 0.85 : 0.35))

                Text(isAvailable ? "ouvert" : "fermé")
                    .font(.system(size: 8))
                    .foregroundStyle(.white.opacity(isAvailable ? 0.4 : 0.2))
            }
            .frame(width: 92, height: 78)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.white.opacity(isHovering ? 0.12 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(source.tint.opacity(isHovering ? 0.5 : 0), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
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
