import SwiftUI

/// Le contenu de l'encoche ouverte quand on choisit l'onglet Claude Code.
struct ClaudePanelView: View {
    @ObservedObject var monitor: ClaudeCodeMonitor

    var body: some View {
        if monitor.sessions.isEmpty {
            empty
        } else {
            list
        }
    }

    private var empty: some View {
        VStack(spacing: 8) {
            ClaudeBurstMark(size: 26)
                .foregroundStyle(.white.opacity(0.35))
            Text("Aucune session")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
            Text(ClaudeHooksInstaller.isInstalled
                 ? "Les hooks sont en place. Lance Claude Code."
                 : "Installe les hooks depuis les réglages.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ForEach(monitor.sessions.prefix(3)) { session in
                ClaudeSessionRow(session: session)
                if session.id != monitor.sessions.prefix(3).last?.id {
                    Divider().overlay(.white.opacity(0.08))
                }
            }

            if monitor.sessions.count > 3 {
                Text("+ \(monitor.sessions.count - 3) autre(s)")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
    }
}

private struct ClaudeSessionRow: View {
    let session: ClaudeSession

    var body: some View {
        HStack(spacing: 10) {
            ActivityDot(activity: session.activity, size: 7)

            VStack(alignment: .leading, spacing: 1) {
                Text(session.project)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(session.detail ?? session.activity.label)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Text(session.activity.label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(session.activity.color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    Capsule().fill(session.activity.color.opacity(0.15))
                )
        }
        .padding(.vertical, 7)
    }
}

/// Pastille d'état, qui pulse tant qu'un tour est en cours.
struct ActivityDot: View {
    let activity: ClaudeActivity
    var size: CGFloat = 6

    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(activity.color)
            .frame(width: size, height: size)
            .opacity(activity.pulses && pulsing ? 0.35 : 1)
            .animation(
                activity.pulses
                    ? .easeInOut(duration: 0.75).repeatForever(autoreverses: true)
                    : .default,
                value: pulsing
            )
            .onAppear { pulsing = true }
    }
}
