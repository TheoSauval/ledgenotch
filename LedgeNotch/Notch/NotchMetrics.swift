import Foundation

/// Dimensions de l'encoche dans ses trois états, et du panneau qui les contient.
///
/// Le panneau ne change jamais de taille : il fait toujours la taille ouverte.
/// C'est le contenu SwiftUI qui s'anime à l'intérieur. Redimensionner une fenêtre
/// 120 fois par seconde produit des à-coups ; animer une forme dedans, non.
struct NotchMetrics {
    let closedSize: CGSize
    let openSize: CGSize
    let peekAmount: CGFloat

    /// Marge ajoutée autour de la taille ouverte pour laisser respirer l'ombre
    /// et les coins rentrants, qui débordent de la forme.
    let padding: CGFloat = 24

    /// - Parameter peekAmount: de combien de points l'encoche s'élargit au survol.
    ///   La hauteur suit à un tiers de cette valeur : grandir autant en hauteur
    ///   qu'en largeur descendrait trop bas sur la barre de menus.
    init(closedSize: CGSize, peekAmount: Double = 30) {
        self.closedSize = closedSize
        self.peekAmount = peekAmount
        // Trois colonnes — musique, miroir, calendrier — demandent de la largeur.
        // En dessous de 720 points, la semaine du calendrier ne tient plus.
        self.openSize = CGSize(
            width: max(closedSize.width * 3.9, 720),
            // 178 points de contenu, plus la bande d'en-tête qui longe le
            // boîtier caméra.
            height: 178 + closedSize.height
        )
    }

    /// L'encoche au survol, qui conserve ses compartiments.
    ///
    /// Sans cette conservation, s'approcher de l'égaliseur pour le cliquer le
    /// ferait disparaître : le survol rétrécirait l'encoche à sa largeur nue
    /// juste avant que le curseur n'arrive dessus.
    func peekSize(withSlots slots: Bool) -> CGSize {
        let base = closedSize(withSlots: slots)
        return CGSize(
            width: base.width + peekAmount,
            height: closedSize.height + peekAmount / 3
        )
    }

    /// Hauteur de la bande d'en-tête de l'encoche ouverte, calée sur celle du
    /// boîtier caméra. Le contenu commence en dessous, sinon il longerait un
    /// endroit où il n'y a pas d'écran.
    var headerHeight: CGFloat { closedSize.height }

    /// Largeur d'un compartiment latéral, de part et d'autre du boîtier caméra.
    ///
    /// Indispensable : entre `auxiliaryTopLeftArea` et `auxiliaryTopRightArea`
    /// il n'y a pas d'écran, seulement le boîtier physique. Tout ce qu'on
    /// dessinerait à l'emplacement de l'encoche serait invisible — présent dans
    /// la mémoire vidéo, donc visible sur une capture, mais pas sur la dalle.
    let sideSlotWidth: CGFloat = 40

    /// L'encoche repliée, élargie quand elle a quelque chose à montrer.
    func closedSize(withSlots slots: Bool) -> CGSize {
        guard slots else { return closedSize }
        return CGSize(
            width: closedSize.width + sideSlotWidth * 2,
            height: closedSize.height
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
