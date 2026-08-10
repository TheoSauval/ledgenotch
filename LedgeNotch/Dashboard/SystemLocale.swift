import Foundation

extension Locale {
    /// La langue réglée sur le Mac, et non celle de l'app.
    ///
    /// `Locale.current` est bornée par les langues que le paquet déclare
    /// prendre en charge. LedgeNotch n'en déclare aucune : les dates
    /// s'affichaient donc en anglais — « August » — sur un système en français.
    /// `preferredLanguages` échappe à cette limite et donne le vrai réglage.
    static let system: Locale = {
        guard let language = Locale.preferredLanguages.first else { return .current }
        return Locale(identifier: language)
    }()
}
