import AppKit
import PDFKit
import UniformTypeIdentifiers

/// Récupère le texte brut d'un document, pour le donner au prompteur.
///
/// `NSAttributedString` sait lire le format d'Office nativement : aucune
/// bibliothèque tierce n'est nécessaire pour ouvrir un `.docx`.
enum ScriptImporter {
    enum Failure: LocalizedError {
        case unreadable(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name):
                return "Impossible de lire « \(name) »."
            }
        }
    }

    static var supportedTypes: [UTType] {
        [
            .plainText,
            .rtf,
            .pdf,
            UTType(filenameExtension: "docx"),
            UTType(filenameExtension: "doc"),
            UTType(filenameExtension: "odt"),
            UTType(filenameExtension: "md"),
        ].compactMap { $0 }
    }

    /// Ouvre le sélecteur de fichiers et renvoie le texte du document choisi.
    @MainActor
    static func pick() throws -> String? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = supportedTypes
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.prompt = "Importer"
        panel.message = "Choisissez le texte à faire défiler."

        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return try read(url)
    }

    static func read(_ url: URL) throws -> String {
        // Le PDF a son propre extracteur ; tout le reste passe par
        // NSAttributedString, qui reconnaît le format à l'extension.
        if url.pathExtension.lowercased() == "pdf" {
            guard let document = PDFDocument(url: url), let text = document.string else {
                throw Failure.unreadable(url.lastPathComponent)
            }
            return clean(text)
        }

        if let attributed = try? NSAttributedString(
            url: url,
            options: [.documentType: documentType(for: url)],
            documentAttributes: nil
        ) {
            return clean(attributed.string)
        }

        // Dernier recours : un fichier texte dont l'encodage n'est pas déclaré.
        if let raw = try? String(contentsOf: url, encoding: .utf8) {
            return clean(raw)
        }

        throw Failure.unreadable(url.lastPathComponent)
    }

    private static func documentType(for url: URL) -> NSAttributedString.DocumentType {
        switch url.pathExtension.lowercased() {
        case "docx", "doc": return .officeOpenXML
        case "rtf": return .rtf
        case "odt": return .openDocument
        default: return .plain
        }
    }

    /// Les documents de traitement de texte regorgent de retours et d'espaces
    /// insécables qui fausseraient le découpage en lignes.
    private static func clean(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}
