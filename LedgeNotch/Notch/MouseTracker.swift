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
    private var onMove: ((CGPoint, Bool) -> Void)?
    private var onClick: ((CGPoint) -> Void)?

    /// Position courante du curseur, en coordonnées écran AppKit.
    var location: CGPoint { NSEvent.mouseLocation }

    /// - Parameter onMove: reçoit la position et un drapeau indiquant qu'un
    ///   bouton est enfoncé — autrement dit qu'un glisser est en cours, ce qui
    ///   permet à l'encoche de s'ouvrir pour accueillir un fichier.
    func start(
        onMove: @escaping (CGPoint, Bool) -> Void,
        onClick: @escaping (CGPoint) -> Void
    ) {
        stop()
        self.onMove = onMove
        self.onClick = onClick

        let hover: NSEvent.EventTypeMask = [.mouseMoved]
        let drags: NSEvent.EventTypeMask = [.leftMouseDragged, .rightMouseDragged]
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown]

        add(global: hover) { [weak self] in self?.onMove?(NSEvent.mouseLocation, false) }
        add(global: drags) { [weak self] in self?.onMove?(NSEvent.mouseLocation, true) }
        add(global: clicks) { [weak self] in self?.onClick?(NSEvent.mouseLocation) }

        // Le moniteur global ne voit pas les événements destinés à notre propre
        // panneau. Sans ce doublon local, l'encoche ouverte cesserait de répondre
        // dès que le curseur entre dedans.
        add(local: hover) { [weak self] in self?.onMove?(NSEvent.mouseLocation, false) }
        add(local: drags) { [weak self] in self?.onMove?(NSEvent.mouseLocation, true) }
        add(local: clicks) { [weak self] in self?.onClick?(NSEvent.mouseLocation) }

        onMove(NSEvent.mouseLocation, false)
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
