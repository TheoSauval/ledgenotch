import SwiftUI

/// Petit égaliseur animé, affiché pendant la lecture.
///
/// Décoratif, pas analytique : lire le niveau sonore réel d'une autre app
/// demanderait de capter la sortie audio du système — une permission de plus et
/// une usine à gaz pour quatre barres de trois points de large. Les hauteurs
/// sont donc fixes, seule la cadence de chacune diffère pour éviter l'effet
/// mécanique d'un mouvement synchrone.
struct SoundBars: View {
    var color: Color = .white
    var height: CGFloat = 14
    /// À l'arrêt, les barres se figent au ras du sol : c'est le signe le plus
    /// lisible qu'il ne se passe plus rien.
    var isActive: Bool = true

    private let ratios: [CGFloat] = [0.5, 1.0, 0.7, 0.9]
    private let durations: [Double] = [0.42, 0.58, 0.36, 0.5]

    @State private var animating = false

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(ratios.indices, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(0.9))
                    .frame(width: 2.5, height: barHeight(at: index))
                    .animation(
                        .easeInOut(duration: durations[index])
                            .repeatForever(autoreverses: true),
                        value: animating
                    )
                    .animation(.easeOut(duration: 0.2), value: isActive)
            }
        }
        .frame(height: height)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }

    private func barHeight(at index: Int) -> CGFloat {
        guard isActive, animating else { return height * 0.22 }
        return height * ratios[index]
    }
}

/// L'égaliseur transformé en bouton lecture/pause, dans l'encoche repliée.
///
/// Au survol, les barres s'effacent au profit de l'icône : sans ça, rien
/// n'indiquerait qu'on peut cliquer — et une icône affichée en permanence
/// ferait perdre l'effet vivant qu'on cherchait.
struct EqualizerButton: View {
    let isPlaying: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                // Viser quatre barres de deux points et demi serait pénible :
                // toute la surface du compartiment est cliquable.
                Color.white.opacity(0.001)

                SoundBars(height: 13, isActive: isPlaying)
                    .opacity(isHovering ? 0 : (isPlaying ? 1 : 0.4))

                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white.opacity(0.9))
                    .opacity(isHovering ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .help(isPlaying ? "Mettre en pause" : "Reprendre la lecture")
    }
}
