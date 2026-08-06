import SwiftUI

struct NotchView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var monitor: ClaudeCodeMonitor
    @ObservedObject var music: MusicController
    let onOpenSettings: () -> Void

    private var size: CGSize { state.currentSize }

    var body: some View {
        VStack(spacing: 0) {
            NotchShape(
                topRadius: topRadius,
                bottomRadius: bottomRadius
            )
            .fill(.black)
            .frame(width: size.width, height: size.height)
            .overlay(alignment: .top) {
                if state.isOpen {
                    openContent
                        .frame(width: size.width, height: size.height)
                        .transition(.opacity)
                } else {
                    // Repliée, l'encoche se contente d'un signe : c'est tout
                    // l'intérêt d'un état ambiant, savoir sans avoir à regarder.
                    closedIndicator
                        .frame(width: size.width, height: size.height, alignment: .trailing)
                        .padding(.trailing, 10)
                        .transition(.opacity)
                }
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 12, y: 6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(animation, value: state.phase)
        .animation(.easeInOut(duration: 0.25), value: monitor.overall)
        .animation(.easeInOut(duration: 0.25), value: music.isPlaying)
    }

    /// Claude passe devant la musique : une session bloquée demande une action,
    /// un morceau qui tourne n'attend rien de personne.
    @ViewBuilder
    private var closedIndicator: some View {
        if let activity = monitor.overall {
            ActivityDot(activity: activity, size: 6)
        } else if music.isPlaying {
            Image(systemName: "music.note")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Contenu déployé

    private var openContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            switch state.panel {
            case .home: homePanel
            case .music: MusicPanelView(music: music)
            case .claude: ClaudePanelView(monitor: monitor)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 22)
        // Sans cette extension, la barre d'icônes se calerait sur la largeur
        // naturelle du contenu au lieu du bord de l'encoche.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) { toolbar }
    }

    private var homePanel: some View {
        VStack(spacing: 8) {
            Image(systemName: "tray.full")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.white.opacity(0.85))
            Text("LedgeNotch")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text("L'étagère à fichiers arrive ici.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var toolbar: some View {
        HStack(spacing: 2) {
            NotchIconButton(
                isSelected: state.panel == .music,
                badge: music.isPlaying ? .white.opacity(0.7) : nil,
                help: "Lecture en cours"
            ) {
                state.panel = state.panel == .music ? .home : .music
                music.refresh()
            } icon: {
                Image(systemName: "music.note")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }

            NotchIconButton(
                isSelected: state.panel == .claude,
                badge: monitor.overall?.color,
                help: "Sessions Claude Code"
            ) {
                state.panel = state.panel == .claude ? .home : .claude
            } icon: {
                ClaudeCodeMark(width: 16)
            }

            NotchIconButton(
                isSelected: false,
                badge: nil,
                help: "Réglages de LedgeNotch",
                action: onOpenSettings
            ) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }
        }
        .padding(.top, 5)
        .padding(.trailing, 10)
    }

    // MARK: - Style

    private var topRadius: CGFloat {
        switch state.phase {
        case .closed: return 8
        case .peek: return 10
        case .open: return 12
        }
    }

    private var bottomRadius: CGFloat {
        switch state.phase {
        case .closed: return 12
        case .peek: return 16
        case .open: return 24
        }
    }

    private var shadowOpacity: Double {
        switch state.phase {
        case .closed: return 0
        case .peek: return 0.18
        case .open: return 0.35
        }
    }

    /// Le survol doit paraître instantané, l'ouverture mérite un peu de rebond.
    private var animation: Animation {
        state.isOpen
            ? .spring(response: 0.34, dampingFraction: 0.72)
            : .spring(response: 0.22, dampingFraction: 0.85)
    }
}

/// Bouton d'icône de l'encoche : discret au repos, franc au survol.
private struct NotchIconButton<Icon: View>: View {
    let isSelected: Bool
    let badge: Color?
    let help: String
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            // Une opacité sur l'ensemble plutôt qu'une couleur imposée : l'icône
            // de Claude Code porte la sienne, et un `foregroundStyle` blanc la
            // laisserait intacte — donc sans la moindre réaction au survol.
            icon()
                .opacity(opacity)
                .frame(width: 26, height: 26)
                .background(
                    Circle().fill(.white.opacity(isSelected ? 0.16 : (isHovering ? 0.12 : 0)))
                )
                .overlay(alignment: .topTrailing) {
                    if let badge {
                        Circle()
                            .fill(badge)
                            .frame(width: 5, height: 5)
                            .offset(x: -2, y: 3)
                    }
                }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .help(help)
    }

    private var opacity: Double {
        if isSelected { return 0.95 }
        return isHovering ? 0.95 : 0.45
    }
}
