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

    private let ratios: [CGFloat] = [0.5, 1.0, 0.7, 0.9]
    private let durations: [Double] = [0.42, 0.58, 0.36, 0.5]

    @State private var animating = false

    var body: some View {
        HStack(alignment: .center, spacing: 2.5) {
            ForEach(ratios.indices, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(0.9))
                    .frame(
                        width: 2.5,
                        height: animating ? height * ratios[index] : height * 0.22
                    )
                    .animation(
                        .easeInOut(duration: durations[index])
                            .repeatForever(autoreverses: true),
                        value: animating
                    )
            }
        }
        .frame(height: height)
        .onAppear { animating = true }
        .onDisappear { animating = false }
    }
}
