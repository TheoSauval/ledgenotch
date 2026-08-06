import Combine
import Foundation

/// Préférences de l'utilisateur, conservées dans `UserDefaults`.
///
/// `@AppStorage` conviendrait dans une vue, mais pas ici : il ne prévient pas les
/// abonnés d'un `ObservableObject`, et le contrôleur a besoin d'être averti pour
/// recalculer ses dimensions.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private enum Key {
        static let openOnHover = "openOnHover"
        static let hapticsEnabled = "hapticsEnabled"
        static let peekAmount = "peekAmount"
    }

    /// Ouvrir l'encoche au simple survol, sans attendre le clic.
    @Published var openOnHover: Bool {
        didSet { defaults.set(openOnHover, forKey: Key.openOnHover) }
    }

    @Published var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Key.hapticsEnabled) }
    }

    /// De combien de points l'encoche dépasse au survol.
    @Published var peekAmount: Double {
        didSet { defaults.set(peekAmount, forKey: Key.peekAmount) }
    }

    static let peekRange: ClosedRange<Double> = 0...80

    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.openOnHover: false,
            Key.hapticsEnabled: true,
            Key.peekAmount: 30.0,
        ])
        openOnHover = defaults.bool(forKey: Key.openOnHover)
        hapticsEnabled = defaults.bool(forKey: Key.hapticsEnabled)
        peekAmount = defaults.double(forKey: Key.peekAmount)
    }

    func resetToDefaults() {
        openOnHover = false
        hapticsEnabled = true
        peekAmount = 30
    }
}
