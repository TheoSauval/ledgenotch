import SwiftUI

/// La page prompteur : le texte défile, la ligne en cours se détache.
struct PrompterPanelView: View {
    @ObservedObject var engine: PrompterEngine
    @ObservedObject var listener: SpeechListener
    @ObservedObject private var preferences = Preferences.shared


    var body: some View {
        if engine.isEmpty {
            empty
        } else {
            HStack(spacing: 16) {
                script
                controls
            }
            .padding(.leading, 24)
            .padding(.trailing, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - Texte

    /// Le texte glisse par décalage plutôt que par `scrollTo` : ce dernier saute
    /// d'une ligne à l'autre, alors qu'on veut un mouvement continu qui suive le
    /// débit de la voix.
    ///
    /// Toutes les lignes ont la même hauteur, garantie par `lineLimit(1)` et un
    /// découpage à quarante-cinq caractères. Mesurer chaque ligne aurait été
    /// plus souple, mais le calcul du décalage devient ici exact et immédiat,
    /// sans dépendre d'une remontée de mesures qui arrive après le premier tracé.
    private var script: some View {
        GeometryReader { geometry in
            VStack(alignment: .leading, spacing: lineSpacing) {
                ForEach(engine.chunks) { chunk in
                    Text(chunk.text)
                        .font(.system(size: preferences.prompterFontSize, weight: weight(for: chunk)))
                        .foregroundStyle(.white.opacity(opacity(for: chunk)))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(height: lineHeight, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            // La ligne en cours se tient au tiers supérieur : plus haut on perd
            // ce qui vient d'être dit, plus bas on ne voit plus assez la suite.
            .offset(y: geometry.size.height * 0.32 - travelled)
            .animation(glide, value: travelled)
        }
        .clipped()
        .frame(maxWidth: .infinity)
    }

    private var lineSpacing: CGFloat { 6 }
    private var lineHeight: CGFloat { preferences.prompterFontSize * 1.45 }

    /// Distance parcourue depuis le début du texte, ligne courante comprise au
    /// prorata de ce qui en a déjà été lu.
    private var travelled: CGFloat {
        let step = lineHeight + lineSpacing
        return (Double(engine.currentChunk) + engine.fractionWithinChunk) * step
    }

    /// Le défilement automatique avance par petits pas réguliers : une
    /// interpolation linéaire de la durée d'un pas donne un mouvement continu.
    /// Un recalage sur la voix, lui, est un saut : il mérite d'être amorti.
    private var glide: Animation {
        engine.isFollowingVoice
            ? .easeOut(duration: 0.4)
            : .linear(duration: PrompterEngine.tick)
    }

    /// La ligne en cours est pleine, celles d'avant s'effacent, celles d'après
    /// restent lisibles : on doit pouvoir anticiper sans perdre où l'on en est.
    private func opacity(for chunk: PrompterEngine.Chunk) -> Double {
        if chunk.id == engine.currentChunk { return 1 }
        return chunk.id < engine.currentChunk ? 0.22 : 0.5
    }

    private func weight(for chunk: PrompterEngine.Chunk) -> Font.Weight {
        chunk.id == engine.currentChunk ? .semibold : .regular
    }

    // MARK: - Commandes

    private var controls: some View {
        VStack(spacing: 9) {
            Button {
                toggleVoice()
            } label: {
                ZStack {
                    Circle()
                        .fill(engine.isFollowingVoice
                              ? Color.red.opacity(0.85)
                              : Color.white.opacity(0.1))
                        .frame(width: 40, height: 40)
                    Image(systemName: engine.isFollowingVoice ? "waveform" : "mic.fill")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .help(engine.isFollowingVoice ? "Arrêter le suivi" : "Suivre la voix")

            HStack(spacing: 6) {
                SmallButton(system: engine.isAutoScrolling ? "pause.fill" : "play.fill") {
                    engine.toggleAutoScroll()
                }
                SmallButton(system: "arrow.counterclockwise") {
                    engine.stopAutoScroll()
                    engine.rewind()
                }
            }

            HStack(spacing: 5) {
                SmallButton(system: "textformat.size.smaller") {
                    preferences.prompterFontSize = max(13, preferences.prompterFontSize - 2)
                }
                SmallButton(system: "textformat.size.larger") {
                    preferences.prompterFontSize = min(28, preferences.prompterFontSize + 2)
                }
            }

            ProgressView(value: engine.progress)
                .progressViewStyle(.linear)
                .tint(.white.opacity(0.5))
                .frame(width: 62)
        }
        .frame(width: 74)
    }

    private func toggleVoice() {
        if engine.isFollowingVoice {
            engine.followVoice(false)
            listener.stop()
        } else {
            // Le prompteur compare ce qui est dit à ce qui est écrit : repartir
            // d'une transcription vide évite qu'une phrase d'une autre page
            // vienne fausser le recalage.
            listener.clear()
            engine.followVoice(true)
            listener.start(locale: preferences.speechSource.locale)
        }
    }

    // MARK: - Aucun texte

    private var empty: some View {
        VStack(spacing: 8) {
            Image(systemName: "text.alignleft")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.3))
            Text("Aucun texte")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Text("Collez votre texte dans les réglages, section Prompteur.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
    }
}

private struct SmallButton: View {
    let system: String
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(isHovering ? 0.95 : 0.6))
                .frame(width: 26, height: 22)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(.white.opacity(isHovering ? 0.14 : 0.07))
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}
