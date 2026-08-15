import SwiftUI
import UniformTypeIdentifiers

/// La page bac : les fichiers déposés, prêts à être repris.
struct ShelfPanelView: View {
    @ObservedObject var shelf: ShelfStore

    @State private var isTargeted = false

    var body: some View {
        Group {
            if shelf.items.isEmpty {
                empty
            } else {
                filled
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .dropDestination(for: URL.self) { urls, _ in
            shelf.add(urls) > 0
        } isTargeted: { targeted in
            isTargeted = targeted
        }
        .overlay {
            if isTargeted {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isTargeted)
    }

    // MARK: - Bac vide

    private var empty: some View {
        VStack(spacing: 7) {
            Image(systemName: isTargeted ? "tray.and.arrow.down.fill" : "tray")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(isTargeted ? 0.85 : 0.35))

            Text(isTargeted ? "Lâchez ici" : "Bac vide")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))

            Text("Déposez des fichiers dans l'encoche ouverte pour les garder sous la main.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)
        }
    }

    // MARK: - Bac rempli

    private var filled: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(shelf.items) { item in
                        ShelfCard(item: item) {
                            shelf.remove(item)
                        } reveal: {
                            shelf.reveal(item)
                        }
                    }
                }
                .padding(.horizontal, 22)
            }
            .scrollIndicators(.hidden)

            HStack(spacing: 8) {
                Text("\(shelf.items.count) élément\(shelf.items.count > 1 ? "s" : "")")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))

                Button("Vider") { shelf.empty() }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
    }
}

private struct ShelfCard: View {
    let item: ShelfItem
    let remove: () -> Void
    let reveal: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 5) {
            Image(nsImage: item.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 42, height: 42)

            Text(item.name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(1)
                .truncationMode(.middle)

            Text(item.readableSize)
                .font(.system(size: 8.5))
                .foregroundStyle(.white.opacity(0.35))
        }
        .frame(width: 86, height: 92)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.white.opacity(isHovering ? 0.12 : 0.06))
        )
        .overlay(alignment: .topTrailing) {
            if isHovering {
                Button(action: remove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.8), .black.opacity(0.6))
                }
                .buttonStyle(.plain)
                .offset(x: 5, y: -5)
                .help("Retirer du bac")
            }
        }
        // `NSItemProvider(contentsOf:)` exporte le fichier lui-même, là qu'un
        // simple texte d'URL ne serait pas reconnu comme un fichier par les
        // autres apps.
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .onHover { isHovering = $0 }
        .onTapGesture(count: 2, perform: reveal)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .help("Glissez pour reprendre — double-clic pour montrer dans le Finder")
    }
}
