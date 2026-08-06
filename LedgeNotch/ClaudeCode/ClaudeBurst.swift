import SwiftUI

/// La marque en étoile de Claude, dessinée plutôt qu'importée.
///
/// Un tracé vectoriel s'adapte à toutes les tailles et prend la couleur qu'on lui
/// donne, ce qu'un PNG ne fait pas. Les rayons sont volontairement irréguliers :
/// répartis parfaitement, l'ensemble ressemblerait à une étoile de shérif.
///
/// À garder en tête si LedgeNotch est un jour publié : le logo d'Anthropic est
/// une marque déposée. Pour un usage personnel c'est sans conséquence.
struct ClaudeBurst: Shape {
    /// Longueur de chaque rayon, en fraction du rayon disponible.
    private static let rays: [CGFloat] = [
        1.0, 0.62, 0.88, 0.55, 0.95, 0.6,
        1.0, 0.58, 0.9, 0.64, 0.85,
    ]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let step = 2 * Double.pi / Double(Self.rays.count)

        var path = Path()
        for (index, length) in Self.rays.enumerated() {
            let angle = step * Double(index) - .pi / 2
            let inner = radius * 0.16
            let outer = radius * length
            path.move(to: CGPoint(
                x: center.x + cos(angle) * inner,
                y: center.y + sin(angle) * inner
            ))
            path.addLine(to: CGPoint(
                x: center.x + cos(angle) * outer,
                y: center.y + sin(angle) * outer
            ))
        }
        return path
    }
}

/// La marque prête à afficher, épaisseur de trait proportionnée à sa taille.
struct ClaudeBurstMark: View {
    var size: CGFloat = 14

    var body: some View {
        ClaudeBurst()
            .stroke(style: StrokeStyle(lineWidth: size * 0.16, lineCap: .round))
            .frame(width: size, height: size)
    }
}
