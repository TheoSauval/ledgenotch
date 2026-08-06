import AppKit
import SwiftUI

/// Fait le lien entre la géométrie de l'écran, le panneau AppKit et l'état SwiftUI.
@MainActor
final class NotchController {
    private let state = NotchState()
    private let tracker = MouseTracker()
    private var panel: NotchPanel?
    private var geometry: NotchGeometry?
    private var pendingClose: DispatchWorkItem?

    /// Délai avant fermeture. Sans lui, l'encoche se referme au moindre
    /// tremblement du curseur près du bord, et l'ensemble paraît nerveux.
    private let closeDelay: TimeInterval = 0.18

    func start() {
        rebuild()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        tracker.start { [weak self] point in
            MainActor.assumeIsolated {
                self?.handleMouse(at: point)
            }
        }
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

        applyPhase()
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

    /// Rectangle réellement occupé par l'encoche ouverte, en coordonnées écran.
    /// Le panneau est plus large que ça (marge pour l'ombre) : se fier à son cadre
    /// pour décider de la fermeture garderait l'encoche ouverte au-dessus du vide.
    private var openRect: CGRect {
        guard let geometry else { return .zero }
        let size = state.metrics.openSize
        return CGRect(
            x: geometry.notchRect.midX - size.width / 2,
            y: geometry.screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    // MARK: - Survol

    private func handleMouse(at point: CGPoint) {
        guard let geometry else { return }

        let inside: Bool
        if state.isOpen {
            inside = openRect.contains(point)
        } else {
            inside = state.metrics.hoverRect(around: geometry.notchRect).contains(point)
        }

        if inside {
            pendingClose?.cancel()
            pendingClose = nil
            setPhase(.open)
        } else if state.isOpen, pendingClose == nil {
            let work = DispatchWorkItem { [weak self] in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.pendingClose = nil
                    self.setPhase(.closed)
                }
            }
            pendingClose = work
            DispatchQueue.main.asyncAfter(deadline: .now() + closeDelay, execute: work)
        }
    }

    private func setPhase(_ phase: NotchState.Phase) {
        guard state.phase != phase else { return }
        state.phase = phase
        applyPhase()
    }

    private func applyPhase() {
        // Fermée, l'encoche doit laisser passer les clics : elle recouvre la barre
        // de menus, et l'utilisateur doit pouvoir cliquer sur l'horloge à travers.
        panel?.ignoresMouseEvents = !state.isOpen
    }

    @objc private func screenParametersChanged() {
        rebuild()
    }
}
