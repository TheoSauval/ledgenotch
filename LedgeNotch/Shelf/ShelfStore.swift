import AppKit
import UniformTypeIdentifiers

struct ShelfItem: Identifiable, Equatable {
    let url: URL
    let size: Int64
    let addedAt: Date

    var id: String { url.path }
    var name: String { url.lastPathComponent }

    var icon: NSImage {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    var readableSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

/// Le bac : des fichiers déposés dans l'encoche, gardés jusqu'à ce qu'on les
/// reprenne.
///
/// Les fichiers sont **copiés**, pas référencés. Une référence se briserait dès
/// que l'original serait déplacé ou vidé de la corbeille, et le bac se viderait
/// tout seul sans prévenir — l'inverse de ce qu'on attend d'un endroit où l'on
/// pose des choses.
@MainActor
final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem] = []

    static let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("LedgeNotch/Bac", isDirectory: true)
    }()

    private let manager = FileManager.default

    init() {
        reload()
    }

    /// L'état du bac se lit dans le dossier lui-même, sans index à côté : deux
    /// sources de vérité finiraient par diverger, et le dossier ne ment jamais.
    func reload() {
        try? manager.createDirectory(at: Self.directory, withIntermediateDirectories: true)

        let contents = (try? manager.contentsOfDirectory(
            at: Self.directory,
            includingPropertiesForKeys: [.fileSizeKey, .addedToDirectoryDateKey, .creationDateKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        items = contents
            .map { url in
                let values = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey])
                return ShelfItem(
                    url: url,
                    size: Int64(values?.fileSize ?? 0),
                    addedAt: values?.creationDate ?? .distantPast
                )
            }
            .sorted { $0.addedAt > $1.addedAt }
    }

    @discardableResult
    func add(_ urls: [URL]) -> Int {
        try? manager.createDirectory(at: Self.directory, withIntermediateDirectories: true)

        var added = 0
        for source in urls {
            let destination = uniqueDestination(for: source.lastPathComponent)
            do {
                try manager.copyItem(at: source, to: destination)
                added += 1
            } catch {
                continue
            }
        }
        if added > 0 { reload() }
        return added
    }

    func remove(_ item: ShelfItem) {
        try? manager.removeItem(at: item.url)
        reload()
    }

    /// Vers la corbeille et non vers le néant : vider le bac par erreur ne doit
    /// pas être irrattrapable.
    func empty() {
        for item in items {
            try? manager.trashItem(at: item.url, resultingItemURL: nil)
        }
        reload()
    }

    func reveal(_ item: ShelfItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.url])
    }

    /// Deux fichiers du même nom ne peuvent pas cohabiter : on numérote plutôt
    /// que d'écraser le premier déposé.
    private func uniqueDestination(for name: String) -> URL {
        var candidate = Self.directory.appendingPathComponent(name)
        guard manager.fileExists(atPath: candidate.path) else { return candidate }

        let base = (name as NSString).deletingPathExtension
        let ext = (name as NSString).pathExtension
        var index = 2
        repeat {
            let numbered = ext.isEmpty ? "\(base) \(index)" : "\(base) \(index).\(ext)"
            candidate = Self.directory.appendingPathComponent(numbered)
            index += 1
        } while manager.fileExists(atPath: candidate.path)

        return candidate
    }
}
