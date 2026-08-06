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

    @Published var phase: Phase = .closed
    @Published var metrics = NotchMetrics(closedSize: NotchGeometry.simulatedSize)

    var currentSize: CGSize {
        switch phase {
        case .closed: return metrics.closedSize
        case .peek: return metrics.peekSize
        case .open: return metrics.openSize
        }
    }

    var isOpen: Bool { phase == .open }
}
