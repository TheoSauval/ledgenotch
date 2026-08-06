import Foundation

/// Surveille le fichier où les hooks de Claude Code déposent leurs événements.
///
/// Un simple fichier en append plutôt qu'un port réseau : pas d'alerte du
/// pare-feu, pas de binaire intermédiaire, et les événements s'accumulent même
/// quand LedgeNotch est arrêté. On peut aussi le lire à la main quand quelque
/// chose cloche, ce qui n'est pas rien pour déboguer une intégration.
@MainActor
final class ClaudeEventLog {
    static let directory = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent(".ledgenotch", isDirectory: true)

    static let fileURL = directory.appendingPathComponent("events.jsonl")

    /// La commande à confier aux hooks. `mkdir -p` la rend auto-réparatrice :
    /// sans lui, un dossier absent ferait échouer le hook et Claude Code
    /// afficherait une erreur à chaque événement.
    nonisolated static let hookCommand =
        "mkdir -p ~/.ledgenotch && { cat; echo; } >> ~/.ledgenotch/events.jsonl"

    /// Au-delà de cette taille, le journal est vidé au démarrage. Seul l'état
    /// courant nous intéresse ; conserver l'historique ne ferait que grossir.
    private static let maxSize: UInt64 = 512 * 1024

    private var source: DispatchSourceFileSystemObject?
    private var descriptor: CInt = -1
    private var offset: UInt64 = 0
    private var handler: ((ClaudeHookEvent) -> Void)?

    func start(onEvent: @escaping (ClaudeHookEvent) -> Void) {
        handler = onEvent
        prepareFile()
        watch()
    }

    func stop() {
        source?.cancel()
        source = nil
        handler = nil
    }

    private func prepareFile() {
        let manager = FileManager.default
        try? manager.createDirectory(at: Self.directory, withIntermediateDirectories: true)

        if !manager.fileExists(atPath: Self.fileURL.path) {
            manager.createFile(atPath: Self.fileURL.path, contents: nil)
        }

        let attributes = try? manager.attributesOfItem(atPath: Self.fileURL.path)
        let size = (attributes?[.size] as? UInt64) ?? 0
        if size > Self.maxSize {
            try? Data().write(to: Self.fileURL)
        }

        // On démarre à la fin du fichier : rejouer l'historique afficherait des
        // sessions terminées depuis longtemps comme si elles venaient de bouger.
        offset = (try? FileHandle(forReadingFrom: Self.fileURL).seekToEnd()) ?? 0
    }

    private func watch() {
        source?.cancel()
        descriptor = open(Self.fileURL.path, O_EVTONLY)
        guard descriptor >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                let mask = self.source?.data ?? []
                if mask.contains(.delete) || mask.contains(.rename) {
                    // Le fichier a été remplacé : le descripteur pointe vers un
                    // inode mort, il faut rouvrir sur le nouveau.
                    self.offset = 0
                    self.prepareFile()
                    self.watch()
                } else {
                    self.readNewLines()
                }
            }
        }

        source.setCancelHandler { [descriptor] in
            close(descriptor)
        }

        self.source = source
        source.resume()
        readNewLines()
    }

    private func readNewLines() {
        guard let handle = try? FileHandle(forReadingFrom: Self.fileURL) else { return }
        defer { try? handle.close() }

        let end = (try? handle.seekToEnd()) ?? 0
        // Fichier vidé sous nos pieds : on repart de zéro plutôt que de lire
        // au-delà de la fin.
        if end < offset { offset = 0 }
        guard end > offset else { return }

        try? handle.seek(toOffset: offset)
        guard let data = try? handle.readToEnd(), !data.isEmpty else { return }
        offset = end

        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(separator: "\n", omittingEmptySubsequences: true) {
            if let event = ClaudeHookEvent.decode(line: String(line)) {
                handler?(event)
            }
        }
    }
}
