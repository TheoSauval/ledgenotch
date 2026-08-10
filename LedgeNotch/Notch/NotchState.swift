import SwiftUI

/// État partagé entre le contrôleur AppKit et la vue SwiftUI.
@MainActor
final class NotchState: ObservableObject {
    /// Trois états plutôt que deux : le survol se contente de faire dépasser
    /// l'encoche, et il faut cliquer pour l'ouvrir. Un simple passage de souris
    /// ne déclenche donc jamais l'ouverture par accident.
    enum Phase {
        case closed
        case peek
        case open
    }

    /// Ce que montre l'encoche une fois ouverte.
    enum Panel {
        case home
        case weather
        case claude
    }

    @Published var phase: Phase = .closed
    @Published var panel: Panel = .home
    @Published var metrics = NotchMetrics(closedSize: NotchGeometry.simulatedSize)

    /// Vrai quand l'encoche repliée a quelque chose à montrer — pochette,
    /// égaliseur, session Claude. Elle s'élargit alors de part et d'autre du
    /// boîtier caméra, seul endroit où ce contenu est réellement visible.
    @Published var sideContent = false

    var currentSize: CGSize {
        switch phase {
        case .closed: return metrics.closedSize(withSlots: sideContent)
        case .peek: return metrics.peekSize(withSlots: sideContent)
        case .open: return metrics.openSize
        }
    }

    var isOpen: Bool { phase == .open }
}
