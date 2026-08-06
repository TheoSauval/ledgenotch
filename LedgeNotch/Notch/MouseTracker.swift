import AppKit

/// Suit la position du curseur à l'échelle du système.
///
/// On n'utilise pas de `NSTrackingArea` : le panneau laisse passer les clics quand
/// il est fermé (`ignoresMouseEvents`), et une zone de suivi ne reçoit alors plus
/// rien. Un moniteur d'événements global voit passer le curseur quelle que soit
/// l'app au premier plan.
///
/// À noter : surveiller la souris ne demande aucune autorisation d'accessibilité,
/// contrairement au clavier.
final class MouseTracker {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var onMove: ((CGPoint) -> Void)?

    /// Position courante du curseur, en coordonnées écran AppKit.
    var location: CGPoint { NSEvent.mouseLocation }

    func start(onMove: @escaping (CGPoint) -> Void) {
        stop()
        self.onMove = onMove

        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in
            guard let self else { return }
            self.onMove?(NSEvent.mouseLocation)
        }

        // Le moniteur global ne voit pas les événements destinés à notre propre
        // panneau : il faut le doublon local pour que l'encoche ouverte ne se
        // referme pas dès que le curseur entre dedans.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            guard let self else { return event }
            self.onMove?(NSEvent.mouseLocation)
            return event
        }

        onMove(NSEvent.mouseLocation)
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        onMove = nil
    }

    deinit {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
    }
}
