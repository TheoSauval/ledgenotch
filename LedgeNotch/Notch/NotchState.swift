import SwiftUI

/// État partagé entre le contrôleur AppKit et la vue SwiftUI.
@MainActor
final class NotchState: ObservableObject {
    enum Phase {
        case closed
        case open
    }

    @Published var phase: Phase = .closed
    @Published var metrics = NotchMetrics(closedSize: NotchGeometry.simulatedSize)

    var currentSize: CGSize {
        switch phase {
        case .closed: return metrics.closedSize
        case .open: return metrics.openSize
        }
    }

    var isOpen: Bool { phase == .open }
}
