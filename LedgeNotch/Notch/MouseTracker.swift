import AppKit

/// Suit la position du curseur et les clics à l'échelle du système.
///
/// On n'utilise pas de `NSTrackingArea` : le panneau laisse passer les clics tant
/// qu'il n'est pas ouvert (`ignoresMouseEvents`), et une zone de suivi ne reçoit
/// alors plus rien. Un moniteur d'événements global voit passer le curseur quelle
/// que soit l'app au premier plan.
///
/// À noter : surveiller la souris ne demande aucune autorisation d'accessibilité,
/// contrairement au clavier.
final class MouseTracker {
    private var monitors: [Any] = []
    private var onMove: ((CGPoint) -> Void)?
    private var onClick: ((CGPoint) -> Void)?

    /// Position courante du curseur, en coordonnées écran AppKit.
    var location: CGPoint { NSEvent.mouseLocation }

    func start(
        onMove: @escaping (CGPoint) -> Void,
        onClick: @escaping (CGPoint) -> Void
    ) {
        stop()
        self.onMove = onMove
        self.onClick = onClick

        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown]

        add(global: moves) { [weak self] in self?.onMove?(NSEvent.mouseLocation) }
        add(global: clicks) { [weak self] in self?.onClick?(NSEvent.mouseLocation) }

        // Le moniteur global ne voit pas les événements destinés à notre propre
        // panneau. Sans ce doublon local, l'encoche ouverte cesserait de répondre
        // dès que le curseur entre dedans.
        add(local: moves) { [weak self] in self?.onMove?(NSEvent.mouseLocation) }
        add(local: clicks) { [weak self] in self?.onClick?(NSEvent.mouseLocation) }

        onMove(NSEvent.mouseLocation)
    }

    func stop() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        onMove = nil
        onClick = nil
    }

    private func add(global mask: NSEvent.EventTypeMask, handler: @escaping () -> Void) {
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { _ in handler() }) {
            monitors.append(monitor)
        }
    }

    private func add(local mask: NSEvent.EventTypeMask, handler: @escaping () -> Void) {
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            handler()
            return event
        }) {
            monitors.append(monitor)
        }
    }

    deinit {
        monitors.forEach(NSEvent.removeMonitor)
    }
}
