import SwiftUI

struct NotchView: View {
    @ObservedObject var state: NotchState
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
                    expandedContent
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
    }

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

    private var expandedContent: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 0)

            Image(systemName: "tray.full")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.white.opacity(0.85))

            Text("LedgeNotch")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)

            Text("Le socle fonctionne.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))

            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        // Sans cette extension, l'engrenage se calerait sur la largeur naturelle
        // du VStack — une centaine de points — au lieu du bord de l'encoche.
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) {
            SettingsButton(action: onOpenSettings)
                .padding(.top, 7)
                .padding(.trailing, 12)
        }
    }
}

/// L'engrenage, en haut à droite de l'encoche ouverte.
///
/// Discret au repos pour ne pas attirer l'œil avant qu'on le cherche, franc au
/// survol pour confirmer qu'il est bien cliquable.
private struct SettingsButton: View {
    let action: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(isHovering ? 0.95 : 0.45))
                .frame(width: 26, height: 26)
                .background(
                    Circle()
                        .fill(.white.opacity(isHovering ? 0.14 : 0))
                )
                .rotationEffect(.degrees(isHovering ? 45 : 0))
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.18), value: isHovering)
        .help("Réglages de LedgeNotch")
    }
}
