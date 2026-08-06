import SwiftUI

/// Couleur et libellé d'une activité, au même endroit pour que la pastille de
/// l'encoche fermée et le panneau ouvert ne se contredisent jamais.
extension ClaudeActivity {
    var color: Color {
        switch self {
        case .working: return Color(red: 0.38, green: 0.65, blue: 1.0)
        case .waiting: return Color(red: 1.0, green: 0.62, blue: 0.16)
        case .done: return Color(red: 0.35, green: 0.85, blue: 0.5)
        case .idle: return Color.white.opacity(0.3)
        }
    }

    var label: String {
        switch self {
        case .working: return "en cours"
        case .waiting: return "attend une réponse"
        case .done: return "terminé"
        case .idle: return "au repos"
        }
    }

    /// Seule l'activité en cours mérite une animation : faire pulser une session
    /// bloquée donnerait l'impression qu'elle avance.
    var pulses: Bool { self == .working }
}
