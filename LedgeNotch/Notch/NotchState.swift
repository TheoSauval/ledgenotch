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
    enum Panel: CaseIterable {
        case home
        case weather
        case deepWork
        case translate
        case claude

        /// Largeur souhaitée par la page.
        ///
        /// L'encoche s'ajuste au contenu : garder la largeur du tableau de bord
        /// pour un minuteur laisserait de larges pans noirs de chaque côté.
        var contentWidth: CGFloat {
            switch self {
            case .home: return 720
            case .weather: return 720
            case .translate: return 700
            case .claude: return 620
            case .deepWork: return 540
            }
        }
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
        case .open: return metrics.openSize(for: panel)
        }
    }

    var isOpen: Bool { phase == .open }
}
