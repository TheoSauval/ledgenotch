import Foundation

/// Les langues proposées à la traduction.
///
/// Une liste fermée plutôt que tout ce que le système sait faire : la
/// reconnaissance vocale et la traduction ne couvrent pas les mêmes langues, et
/// proposer un choix qui échoue ensuite serait pire que de ne pas le proposer.
enum TranslationLanguage: String, CaseIterable, Identifiable {
    case french = "fr-FR"
    case english = "en-US"
    case spanish = "es-ES"
    case german = "de-DE"
    case italian = "it-IT"
    case portuguese = "pt-BR"
    case dutch = "nl-NL"
    case japanese = "ja-JP"
    case korean = "ko-KR"
    case chinese = "zh-CN"
    case arabic = "ar-SA"
    case russian = "ru-RU"

    var id: String { rawValue }

    var locale: Locale { Locale(identifier: rawValue) }

    /// Le code court, seul attendu par le framework de traduction.
    var language: Locale.Language {
        Locale.Language(identifier: String(rawValue.prefix(2)))
    }

    var displayName: String {
        switch self {
        case .french: return "Français"
        case .english: return "Anglais"
        case .spanish: return "Espagnol"
        case .german: return "Allemand"
        case .italian: return "Italien"
        case .portuguese: return "Portugais"
        case .dutch: return "Néerlandais"
        case .japanese: return "Japonais"
        case .korean: return "Coréen"
        case .chinese: return "Chinois"
        case .arabic: return "Arabe"
        case .russian: return "Russe"
        }
    }

    var flag: String {
        switch self {
        case .french: return "🇫🇷"
        case .english: return "🇬🇧"
        case .spanish: return "🇪🇸"
        case .german: return "🇩🇪"
        case .italian: return "🇮🇹"
        case .portuguese: return "🇧🇷"
        case .dutch: return "🇳🇱"
        case .japanese: return "🇯🇵"
        case .korean: return "🇰🇷"
        case .chinese: return "🇨🇳"
        case .arabic: return "🇸🇦"
        case .russian: return "🇷🇺"
        }
    }
}
