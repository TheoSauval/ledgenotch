import AppKit

/// La fenêtre posée par-dessus la barre de menus.
///
/// Trois réglages font tout le travail :
/// - un `level` supérieur à `.mainMenu`, sinon la barre de menus passe devant ;
/// - `.nonactivatingPanel`, pour ne jamais voler le focus à l'app en cours ;
/// - un `collectionBehavior` qui la fait suivre l'utilisateur d'un bureau à l'autre
///   et survivre au plein écran.
final class NotchPanel: NSPanel {
    /// La barre de menus occupe la couche 24, ses icônes de droite la couche 25.
    /// Un cran au-dessus suffit à passer devant les deux, sans aller déranger
    /// les menus déroulants (101) ni Mission Control.
    static let defaultLevel = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        collectionBehavior = [
            .canJoinAllSpaces,
            .stationary,
            .fullScreenAuxiliary,
            .ignoresCycle,
        ]

        isFloatingPanel = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        isMovable = false
        isMovableByWindowBackground = false
        hidesOnDeactivate = false
        animationBehavior = .none
        isReleasedWhenClosed = false

        // Impérativement en dernier : `isFloatingPanel = true` réécrit le niveau
        // à `.floating` (3), soit très en dessous de la barre de menus. Défini
        // avant, notre niveau est silencieusement écrasé et la barre de menus
        // repasse devant l'encoche.
        level = DebugOptions.windowLevel ?? Self.defaultLevel
    }

    // Un panneau qui prend le focus ferait perdre le curseur à l'app active.
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    /// macOS repousse par défaut toute fenêtre qui empiète sur la barre de menus,
    /// y compris les fenêtres sans bordure. Sans cette surcharge, le panneau se
    /// retrouve systématiquement décalé sous l'encoche au lieu de la recouvrir.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }
}
