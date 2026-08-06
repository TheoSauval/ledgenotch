import Foundation

/// Dimensions de l'encoche dans ses trois états, et du panneau qui les contient.
///
/// Le panneau ne change jamais de taille : il fait toujours la taille ouverte.
/// C'est le contenu SwiftUI qui s'anime à l'intérieur. Redimensionner une fenêtre
/// 120 fois par seconde produit des à-coups ; animer une forme dedans, non.
struct NotchMetrics {
    let closedSize: CGSize
    let peekSize: CGSize
    let openSize: CGSize

    /// Marge ajoutée autour de la taille ouverte pour laisser respirer l'ombre
    /// et les coins rentrants, qui débordent de la forme.
    let padding: CGFloat = 24

    /// - Parameter peekAmount: de combien de points l'encoche s'élargit au survol.
    ///   La hauteur suit à un tiers de cette valeur : grandir autant en hauteur
    ///   qu'en largeur descendrait trop bas sur la barre de menus.
    init(closedSize: CGSize, peekAmount: Double = 30) {
        self.closedSize = closedSize
        self.peekSize = CGSize(
            width: closedSize.width + peekAmount,
            height: closedSize.height + peekAmount / 3
        )
        self.openSize = CGSize(
            width: max(closedSize.width * 2.1, 420),
            height: 190
        )
    }

    var panelSize: CGSize {
        CGSize(
            width: openSize.width + padding * 2,
            height: openSize.height + padding
        )
    }

    /// Zone sensible quand l'encoche est fermée.
    ///
    /// On l'agrandit un peu vers le bas : viser 32 points de haut à la souris est
    /// pénible, et l'utilisateur qui descend depuis le bord de l'écran doit
    /// déclencher le survol sans avoir à être précis.
    func hoverRect(around notchRect: CGRect) -> CGRect {
        notchRect.insetBy(dx: -4, dy: 0).offsetBy(dx: 0, dy: -6)
            .union(notchRect)
    }
}
