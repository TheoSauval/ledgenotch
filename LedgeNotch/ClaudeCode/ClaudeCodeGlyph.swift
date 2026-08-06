import SwiftUI

/// La créature en pixels de Claude Code, redessinée en vectoriel.
///
/// Un tracé plutôt qu'un PNG : il reste net à toutes les tailles, prend la
/// couleur qu'on lui donne et n'ajoute aucune ressource au paquet.
///
/// À garder en tête si LedgeNotch est un jour publié : cette marque appartient
/// à Anthropic. Pour un usage personnel c'est sans conséquence.
struct ClaudeCodeGlyph: Shape {
    /// Une chaîne par rangée, `#` pour une case pleine. La grille fait 16 × 10
    /// et l'ensemble est symétrique : yeux à deux cases des bords du corps,
    /// pattes à une et trois cases.
    private static let sprite = [
        "..############..",
        "..############..",
        "..##.######.##..",
        "..##.######.##..",
        "################",
        "################",
        "..############..",
        "..############..",
        "...#.#....#.#...",
        "...#.#....#.#...",
    ]

    private static let columns = 16
    private static let rows = 10

    static let aspectRatio = CGFloat(columns) / CGFloat(rows)

    func path(in rect: CGRect) -> Path {
        let cell = min(rect.width / CGFloat(Self.columns), rect.height / CGFloat(Self.rows))
        let originX = rect.midX - cell * CGFloat(Self.columns) / 2
        let originY = rect.midY - cell * CGFloat(Self.rows) / 2

        // Les cases voisines se chevauchent d'un cheveu : bord à bord,
        // l'anticrénelage laisse apparaître de fines rayures claires entre elles.
        let bleed = cell * 0.02

        var path = Path()
        for (row, line) in Self.sprite.enumerated() {
            // On fusionne les cases pleines d'une même rangée en un seul
            // rectangle, ce qui réduit d'autant les jointures à masquer.
            var runStart: Int?
            for column in 0...Self.columns {
                let filled = column < Self.columns
                    && Array(line)[column] == "#"

                if filled, runStart == nil {
                    runStart = column
                } else if !filled, let start = runStart {
                    path.addRect(
                        CGRect(
                            x: originX + CGFloat(start) * cell - bleed,
                            y: originY + CGFloat(row) * cell - bleed,
                            width: CGFloat(column - start) * cell + bleed * 2,
                            height: cell + bleed * 2
                        )
                    )
                    runStart = nil
                }
            }
        }
        return path
    }
}

extension Color {
    /// L'orange de Claude, relevé sur l'icône.
    static let claudeOrange = Color(red: 0.847, green: 0.467, blue: 0.341)
}

/// La marque prête à afficher, dans ses proportions d'origine.
struct ClaudeCodeMark: View {
    var width: CGFloat = 16
    var color: Color = .claudeOrange

    var body: some View {
        ClaudeCodeGlyph()
            .fill(color)
            .frame(width: width, height: width / ClaudeCodeGlyph.aspectRatio)
    }
}
