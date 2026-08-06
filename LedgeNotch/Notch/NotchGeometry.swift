import AppKit

/// Géométrie de l'encoche d'un écran donné.
///
/// Tous les rectangles sont exprimés dans le repère écran d'AppKit :
/// origine en bas à gauche de l'écran principal, axe Y vers le haut.
struct NotchGeometry {
    /// Rectangle occupé par l'encoche elle-même.
    let notchRect: CGRect
    /// `false` quand l'encoche est simulée (écran externe, MacBook sans encoche).
    let isPhysical: Bool
    let screen: NSScreen

    /// Taille utilisée pour la fausse encoche, calquée sur celle d'un MacBook Pro 14".
    static let simulatedSize = CGSize(width: 200, height: 32)

    /// Calcule la géométrie de l'encoche pour un écran.
    ///
    /// Sur un Mac à encoche, `safeAreaInsets.top` donne sa hauteur et les deux
    /// zones auxiliaires donnent la largeur disponible de part et d'autre : ce qui
    /// reste au milieu, c'est l'encoche. Sur les autres écrans on en simule une,
    /// sinon il n'y aurait rien à tester.
    static func detect(on screen: NSScreen) -> NotchGeometry {
        let frame = screen.frame

        if let physical = physicalNotchRect(on: screen) {
            return NotchGeometry(notchRect: physical, isPhysical: true, screen: screen)
        }

        let size = simulatedSize
        let rect = CGRect(
            x: frame.midX - size.width / 2,
            y: frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        return NotchGeometry(notchRect: rect, isPhysical: false, screen: screen)
    }

    private static func physicalNotchRect(on screen: NSScreen) -> CGRect? {
        let height = screen.safeAreaInsets.top
        guard height > 0 else { return nil }

        guard
            let left = screen.auxiliaryTopLeftArea,
            let right = screen.auxiliaryTopRightArea
        else { return nil }

        let frame = screen.frame
        let width = frame.width - left.width - right.width
        guard width > 0 else { return nil }

        return CGRect(
            x: frame.minX + left.width,
            y: frame.maxY - height,
            width: width,
            height: height
        )
    }

    /// L'écran à utiliser : celui qui porte une vraie encoche, sinon l'écran principal.
    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}
