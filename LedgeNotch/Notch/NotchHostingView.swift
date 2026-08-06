import SwiftUI

/// Hôte SwiftUI qui ignore la zone de sécurité de l'écran.
///
/// Par défaut, AppKit décale le contenu sous l'encoche pour lui éviter d'être
/// masqué. C'est le bon comportement pour une app normale, et exactement
/// l'inverse de ce qu'on veut ici : notre vue doit *recouvrir* l'encoche.
final class NotchHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
    }

    /// Le panneau ne devient jamais fenêtre active : tout clic est donc un
    /// « premier clic ». Sans cette surcharge, il servirait seulement à donner le
    /// focus et le contenu ne le verrait pas passer.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    required init(rootView: Content) {
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) n'est pas utilisé")
    }
}
