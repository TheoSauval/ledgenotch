import SwiftUI

struct NotchView: View {
    @ObservedObject var state: NotchState

    private var size: CGSize { state.currentSize }

    var body: some View {
        VStack(spacing: 0) {
            NotchShape(
                topRadius: state.isOpen ? 12 : 8,
                bottomRadius: state.isOpen ? 24 : 12
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
            .shadow(color: .black.opacity(state.isOpen ? 0.35 : 0), radius: 12, y: 6)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.phase)
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
