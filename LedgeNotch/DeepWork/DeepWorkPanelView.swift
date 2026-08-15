import SwiftUI

/// La page travail concentré : un anneau, un décompte, et de quoi le lancer.
struct DeepWorkPanelView: View {
    @ObservedObject var timer: DeepWorkTimer

    var body: some View {
        // Sans Spacer ni marge de gauche, le bloc se centre de lui-même : le
        // caler à gauche laisserait tout le côté droit vide.
        HStack(spacing: 34) {
            ring

            VStack(alignment: .leading, spacing: 12) {
                presets
                controls
                tally
            }
        }
        .padding(.bottom, 6)
    }

    // MARK: - Anneau

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.1), lineWidth: 7)

            Circle()
                .trim(from: 0, to: timer.progress)
                .stroke(
                    timer.state == .paused ? Color.orange : Color.accentColor,
                    style: StrokeStyle(lineWidth: 7, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 0.25), value: timer.progress)

            VStack(spacing: 1) {
                Text(timer.clock)
                    .font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .monospacedDigit()

                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .frame(width: 112, height: 112)
    }

    private var label: String {
        switch timer.state {
        case .idle: return "prêt"
        case .running: return "en cours"
        case .paused: return "en pause"
        }
    }

    // MARK: - Réglages

    private var presets: some View {
        HStack(spacing: 6) {
            ForEach(DeepWorkTimer.presets, id: \.self) { value in
                PresetButton(
                    minutes: Int(value / 60),
                    isSelected: timer.duration == value,
                    // Changer de durée en pleine séance remettrait le décompte
                    // à zéro sans prévenir : on l'interdit tant qu'elle tourne.
                    isEnabled: timer.state == .idle
                ) {
                    timer.choose(value)
                }
            }
        }
    }

    private var controls: some View {
        HStack(spacing: 10) {
            Button(action: timer.toggle) {
                HStack(spacing: 6) {
                    Image(systemName: timer.state == .running ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .bold))
                    Text(timer.state == .running ? "Pause" : (timer.state == .paused ? "Reprendre" : "Démarrer"))
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(Capsule().fill(Color.accentColor.opacity(0.85)))
            }
            .buttonStyle(.plain)

            if timer.isActive {
                Button("Arrêter") { timer.reset() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    private var tally: some View {
        HStack(spacing: 5) {
            ForEach(0..<max(timer.completedToday, 1), id: \.self) { index in
                Circle()
                    .fill(index < timer.completedToday
                          ? Color.accentColor.opacity(0.8)
                          : Color.white.opacity(0.12))
                    .frame(width: 6, height: 6)
            }

            Text(timer.completedToday == 0
                 ? "Aucune séance aujourd'hui"
                 : "\(timer.completedToday) séance\(timer.completedToday > 1 ? "s" : "") aujourd'hui")
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.35))
                .padding(.leading, 3)
        }
    }
}

private struct PresetButton: View {
    let minutes: Int
    let isSelected: Bool
    let isEnabled: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Text("\(minutes) min")
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(.white.opacity(isSelected ? 0.95 : 0.45))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule().fill(.white.opacity(isSelected ? 0.16 : (isHovering ? 0.08 : 0.04)))
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

/// Le décompte tel qu'il apparaît sur l'encoche repliée : un anneau de vingt
/// points, avec les minutes restantes au centre.
struct DeepWorkBadge: View {
    let progress: Double
    let minutes: Int
    let isPaused: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 2)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    isPaused ? Color.orange : Color.accentColor,
                    style: StrokeStyle(lineWidth: 2, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            Text("\(minutes)")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .monospacedDigit()
        }
        .frame(width: 22, height: 22)
    }
}
