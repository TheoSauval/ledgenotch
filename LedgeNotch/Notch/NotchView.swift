import SwiftUI

struct NotchView: View {
    @ObservedObject var state: NotchState

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

    /// Contenu provisoire : il sera remplacé par l'étagère à fichiers.
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
    }
}
