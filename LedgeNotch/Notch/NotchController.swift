import AppKit
import SwiftUI

/// Fait le lien entre la géométrie de l'écran, le panneau AppKit et l'état SwiftUI.
///
/// Le déroulé voulu : le curseur arrive sur l'encoche, elle dépasse un peu (`peek`) ;
/// un clic l'ouvre pour de bon (`open`) ; on la referme en cliquant ailleurs ou en
/// éloignant le curseur.
@MainActor
final class NotchController {
    private let state = NotchState()
    private let tracker = MouseTracker()
    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private var pendingClose: DispatchWorkItem?

    /// Délai avant fermeture. Sans lui, l'encoche se referme au moindre
    /// tremblement du curseur près du bord, et l'ensemble paraît nerveux.
    /// Plus long une fois ouverte : l'utilisateur a cliqué pour en arriver là,
    /// ce serait vexant de le lui reprendre au premier écart.
    private var closeDelay: TimeInterval {
        state.isOpen ? 0.45 : 0.18
    }

    func start() {
        rebuild()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        if DebugOptions.forceOpen {
            state.phase = .open
            return
        }

        tracker.start(
            onMove: { [weak self] point in
                MainActor.assumeIsolated { self?.handleMouse(at: point) }
            },
            onClick: { [weak self] point in
                MainActor.assumeIsolated { self?.handleClick(at: point) }
            }
        )
    }

    func stop() {
        tracker.stop()
        pendingClose?.cancel()
        NotificationCenter.default.removeObserver(self)
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Construction

    private func rebuild() {
        guard let screen = NotchGeometry.preferredScreen() else { return }

        let geometry = NotchGeometry.detect(on: screen)
        self.geometry = geometry
        state.metrics = NotchMetrics(closedSize: geometry.notchRect.size)

        let panel = self.panel ?? makePanel()
        panel.setFrame(panelFrame(for: geometry), display: true)
        panel.orderFrontRegardless()
        self.panel = panel

        updateMousePassthrough(at: tracker.location)
    }

    private func makePanel() -> NotchPanel {
        let panel = NotchPanel(contentRect: .zero)
        let hosting = NotchHostingView(rootView: NotchView(state: state))
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        return panel
    }

    private func panelFrame(for geometry: NotchGeometry) -> NSRect {
        let size = state.metrics.panelSize
        let screenFrame = geometry.screen.frame
        return NSRect(
            x: geometry.notchRect.midX - size.width / 2,
            y: screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Rectangle réellement occupé par la forme, en coordonnées écran.
    ///
    /// Le panneau est plus grand que ça (marge pour l'ombre) : se fier à son cadre
    /// pour décider de la fermeture garderait l'encoche ouverte au-dessus du vide.
    private func rect(for phase: NotchState.Phase) -> CGRect {
        guard let geometry else { return .zero }
        let size: CGSize
        switch phase {
        case .closed: size = state.metrics.closedSize
        case .peek: size = state.metrics.peekSize
        case .open: size = state.metrics.openSize
        }
        return CGRect(
            x: geometry.notchRect.midX - size.width / 2,
            y: geometry.screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    /// Zone à l'intérieur de laquelle le curseur maintient l'état courant.
    private func activeRect() -> CGRect {
        guard let geometry else { return .zero }
        switch state.phase {
        case .closed: return state.metrics.hoverRect(around: geometry.notchRect)
        case .peek: return rect(for: .peek)
        case .open: return rect(for: .open)
        }
    }

    // MARK: - Survol et clic

    private func handleMouse(at point: CGPoint) {
        guard geometry != nil else { return }

        if activeRect().contains(point) {
            pendingClose?.cancel()
            pendingClose = nil
            if state.phase == .closed {
                setPhase(.peek)
                Haptics.peek()
            }
        } else if state.phase != .closed {
            scheduleClose()
        }

        updateMousePassthrough(at: point)
    }

    private func handleClick(at point: CGPoint) {
        switch state.phase {
        case .closed:
            break
        case .peek:
            guard rect(for: .peek).contains(point) else { return }
            setPhase(.open)
            Haptics.open()
        case .open:
            // Un clic hors de l'encoche ouverte la referme, sans attendre le délai.
            guard !rect(for: .open).contains(point) else { return }
            pendingClose?.cancel()
            pendingClose = nil
            setPhase(.closed)
            Haptics.close()
        }
        updateMousePassthrough(at: point)
    }

    private func scheduleClose() {
        guard pendingClose == nil else { return }
        let wasOpen = state.isOpen
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.pendingClose = nil
                self.setPhase(.closed)
                if wasOpen { Haptics.close() }
                self.updateMousePassthrough(at: self.tracker.location)
            }
        }
        pendingClose = work
        DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay, execute: work)
    }

    private func setPhase(_ phase: NotchState.Phase) {
        guard state.phase != phase else { return }
        state.phase = phase
    }

    /// Le panneau ne doit intercepter les clics que là où il y a vraiment quelque
    /// chose à cliquer. Partout ailleurs il recouvre la barre de menus, et
    /// l'utilisateur doit pouvoir atteindre l'horloge à travers.
    private func updateMousePassthrough(at point: CGPoint) {
        let interactive = state.isOpen && rect(for: .open).contains(point)
        panel?.ignoresMouseEvents = !interactive
    }

    @objc private func screenParametersChanged() {
        rebuild()
    }
}
