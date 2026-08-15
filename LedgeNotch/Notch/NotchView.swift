import SwiftUI

struct NotchView: View {
    @ObservedObject var state: NotchState
    @ObservedObject var monitor: ClaudeCodeMonitor
    @ObservedObject var music: MusicController
    @ObservedObject var calendar: CalendarService
    @ObservedObject var mirror: MirrorSession
    @ObservedObject var weather: WeatherService
    @ObservedObject var listener: SpeechListener
    @ObservedObject var deepWork: DeepWorkTimer
    @ObservedObject var prompter: PrompterEngine
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
                } else if state.sideContent {
                    // Repliée, l'encoche se contente d'un signe : c'est tout
                    // l'intérêt d'un état ambiant, savoir sans avoir à regarder.
                    closedSlots
                        .frame(width: size.width, height: size.height)
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
        .animation(.easeInOut(duration: 0.25), value: deepWork.state)
        .animation(.spring(response: 0.3, dampingFraction: 0.82), value: state.panel)
    }

    /// Les deux compartiments de l'encoche repliée, de part et d'autre du
    /// boîtier caméra. Rien ne doit être placé entre eux : il n'y a pas d'écran
    /// à cet endroit, seulement le boîtier physique.
    private var closedSlots: some View {
        HStack(spacing: 0) {
            artworkSlot.frame(width: state.metrics.sideSlotWidth)
            Spacer(minLength: 0)
            equalizerSlot.frame(width: state.metrics.sideSlotWidth)
        }
    }

    /// Quand le compartiment de gauche est occupé par une séance, la pochette
    /// vient se glisser derrière l'égaliseur plutôt que de disparaître : les
    /// deux informations tiennent alors dans un seul carré.
    @ViewBuilder
    private var equalizerSlot: some View {
        if music.track != nil {
            EqualizerButton(
                isPlaying: music.isPlaying,
                artwork: deepWork.isActive ? music.artwork : nil,
                action: music.playPause
            )
        }
    }

    /// Le compartiment gauche, par ordre de priorité.
    ///
    /// Une séance de concentration passe devant tout : elle est bornée dans le
    /// temps et c'est précisément son décompte qu'on veut surveiller. Vient
    /// ensuite la pochette. Quand une session Claude réclame l'attention, sa
    /// pastille se pose en écusson plutôt que de disparaître — elle demande une
    /// action, là qu'un morceau qui tourne n'attend rien de personne.
    @ViewBuilder
    private var artworkSlot: some View {
        if deepWork.isActive {
            DeepWorkBadge(
                progress: deepWork.progress,
                minutes: Int(deepWork.remaining.rounded(.up)) / 60,
                isPaused: deepWork.state == .paused
            )
        } else if let artwork = music.artwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 22, height: 22)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                .overlay(alignment: .topTrailing) {
                    if let activity = monitor.overall {
                        Circle()
                            .fill(activity.color)
                            .frame(width: 6, height: 6)
                            .overlay(Circle().stroke(.black, lineWidth: 1.2))
                            .offset(x: 2, y: -2)
                    }
                }
        } else if let activity = monitor.overall {
            ActivityDot(activity: activity, size: 6)
        } else if music.track != nil {
            Image(systemName: music.source?.symbolName ?? "music.note")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Contenu déployé

    private var openContent: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                switch state.panel {
                case .home:
                    HomeDashboardView(music: music, calendar: calendar, mirror: mirror)
                case .weather:
                    WeatherPanelView(weather: weather)
                case .deepWork:
                    DeepWorkPanelView(timer: deepWork)
                case .translate:
                    TranslatePanelView(listener: listener)
                case .claude:
                    ClaudePanelView(monitor: monitor)
                case .prompter:
                    PrompterPanelView(engine: prompter, listener: listener)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// La bande qui longe le boîtier caméra, et sous laquelle commence le contenu.
    ///
    /// Son centre n'est pas affiché — c'est le boîtier — d'où les onglets calés
    /// à gauche et l'engrenage à droite, sans rien entre les deux.
    private var header: some View {
        HStack(spacing: 4) {
            NotchTab(
                title: "Accueil",
                isSelected: state.panel == .home,
                badge: nil
            ) {
                state.panel = .home
            } icon: {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }

            NotchTab(
                title: "Météo",
                isSelected: state.panel == .weather,
                badge: nil
            ) {
                state.panel = .weather
            } icon: {
                Image(systemName: weather.report?.symbolName ?? "cloud.sun.fill")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }

            NotchTab(
                title: "Concentration",
                isSelected: state.panel == .deepWork,
                badge: deepWork.state == .running ? .accentColor : nil
            ) {
                state.panel = .deepWork
            } icon: {
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }

            NotchTab(
                title: "Traduction",
                isSelected: state.panel == .translate,
                badge: listener.isListening ? .red : nil
            ) {
                state.panel = .translate
            } icon: {
                Image(systemName: "character.bubble.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }

            NotchTab(
                title: "Claude",
                isSelected: state.panel == .claude,
                badge: monitor.overall?.color
            ) {
                state.panel = .claude
            } icon: {
                ClaudeCodeMark(width: 15)
            }

            Spacer(minLength: 0)

            // À droite du boîtier plutôt qu'à gauche : la rangée de gauche
            // arrive à saturation, et cet espace-là était inutilisé.
            NotchTab(
                title: "Prompteur",
                isSelected: state.panel == .prompter,
                badge: prompter.isFollowingVoice ? .red : nil
            ) {
                state.panel = .prompter
            } icon: {
                Image(systemName: "text.alignleft")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
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
        .padding(.horizontal, 12)
        .frame(height: state.metrics.headerHeight)
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

/// Onglet de l'en-tête.
///
/// Seul l'onglet actif porte son nom ; les autres se réduisent à leur icône.
/// Ce n'est pas un choix esthétique : la rangée doit tenir entre le bord gauche
/// de l'encoche et le boîtier caméra, soit environ 250 points. Quatre libellés
/// complets débordaient derrière le boîtier, et les derniers onglets devenaient
/// littéralement invisibles — présents dans la mémoire vidéo, donc sur les
/// captures d'écran, mais pas sur la dalle.
private struct NotchTab<Icon: View>: View {
    let title: String
    let isSelected: Bool
    let badge: Color?
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                icon()
            }
            .opacity(isSelected ? 1 : (isHovering ? 0.9 : 0.45))
            .padding(.horizontal, 7)
            .padding(.vertical, 5)
            .background(
                Capsule().fill(.white.opacity(isSelected ? 0.14 : (isHovering ? 0.07 : 0)))
            )
            .overlay(alignment: .topTrailing) {
                if let badge {
                    Circle()
                        .fill(badge)
                        .frame(width: 5, height: 5)
                        .offset(x: 1, y: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .help(title)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isSelected)
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
