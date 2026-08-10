import AppKit
import EventKit
import SwiftUI

/// La vue par défaut de l'encoche ouverte : trois colonnes côte à côte.
///
/// Un tableau de bord plutôt qu'un onglet à choisir. L'encoche s'ouvre une
/// seconde, le temps d'un coup d'œil : obliger à cliquer sur un onglet avant de
/// voir quoi que ce soit annulerait tout l'intérêt.
struct HomeDashboardView: View {
    @ObservedObject var music: MusicController
    @ObservedObject var calendar: CalendarService
    @ObservedObject var mirror: MirrorSession

    var body: some View {
        HStack(spacing: 0) {
            MusicColumn(music: music)
                .frame(maxWidth: .infinity)

            divider

            MirrorColumn(mirror: mirror)
                .frame(width: 150)

            divider

            CalendarColumn(calendar: calendar)
                .frame(width: 290)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 6)
    }

    private var divider: some View {
        Rectangle()
            .fill(.white.opacity(0.09))
            .frame(width: 1)
            .padding(.vertical, 8)
    }
}

// MARK: - Musique

private struct MusicColumn: View {
    @ObservedObject var music: MusicController

    var body: some View {
        if let track = music.track {
            player(track)
        } else {
            launcher
        }
    }

    private func player(_ track: MusicTrack) -> some View {
        HStack(spacing: 11) {
            artwork(for: track)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)

                if !track.subtitle.isEmpty {
                    Text(track.subtitle)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                HStack(spacing: 8) {
                    TransportButton(system: "backward.fill", size: 11, action: music.previous)
                    TransportButton(
                        system: track.isPlaying ? "pause.fill" : "play.fill",
                        size: 15,
                        action: music.playPause
                    )
                    TransportButton(system: "forward.fill", size: 11, action: music.next)
                    Spacer(minLength: 0)
                    sourceButton
                }
            }
            .frame(height: 72, alignment: .topLeading)
        }
        .padding(.trailing, 14)
    }

    private func artwork(for track: MusicTrack) -> some View {
        Group {
            if let image = music.artwork {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color.white.opacity(0.07)
                    Image(systemName: track.source.symbolName)
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(.white.opacity(0.3))
                }
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }

    private var sourceButton: some View {
        Button { music.choose(nil) } label: {
            HStack(spacing: 2) {
                Text(music.source?.displayName ?? "Source")
                Image(systemName: "chevron.down").font(.system(size: 6, weight: .bold))
            }
            .font(.system(size: 8.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.3))
        }
        .buttonStyle(.plain)
        .help("Changer de source")
    }

    private var launcher: some View {
        VStack(spacing: 9) {
            VStack(spacing: 1) {
                Text("Aucun lecteur en cours")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Text("Envie d'en lancer un ?")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 12) {
                ForEach(MusicApp.allCases) { source in
                    SourceIcon(source: source) { open(source) }
                }
            }
        }
        .padding(.trailing, 14)
    }

    /// Choisir la source et l'ouvrir dans la foulée : cliquer une icône de
    /// lecteur pour ne rien voir se passer serait déroutant.
    private func open(_ source: MusicApp) {
        music.choose(source)

        switch source {
        case .youtube:
            guard !source.isAvailable, let url = URL(string: "https://www.youtube.com") else { return }
            NSWorkspace.shared.open(url)
        case .appleMusic, .spotify:
            guard
                !source.isAvailable,
                let identifier = source.bundleIdentifier,
                let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier)
            else { return }
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }
}

private struct SourceIcon: View {
    let source: MusicApp
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(source.tint.opacity(source.isAvailable ? 1 : 0.35))
                .frame(width: 42, height: 42)
                .overlay(
                    Image(systemName: source.symbolName)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .scaleEffect(isHovering ? 1.08 : 1)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: isHovering)
        .help(source.isAvailable ? source.displayName : "Ouvrir \(source.displayName)")
    }
}

private struct TransportButton: View {
    let system: String
    let size: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: system)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(.white.opacity(isHovering ? 1 : 0.7))
                .frame(width: size + 8, height: size + 8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .animation(.easeOut(duration: 0.15), value: isHovering)
    }
}

// MARK: - Miroir

private struct MirrorColumn: View {
    @ObservedObject var mirror: MirrorSession

    var body: some View {
        Button(action: mirror.toggle) {
            ZStack {
                Circle().fill(.white.opacity(0.07))

                if mirror.isRunning {
                    MirrorPreview(session: mirror.session)
                        .clipShape(Circle())
                } else {
                    VStack(spacing: 5) {
                        Image(systemName: mirror.isDenied ? "video.slash" : "camera")
                            .font(.system(size: 19, weight: .light))
                            .foregroundStyle(.white.opacity(0.45))
                        Text(mirror.isDenied ? "Refusé" : "Miroir")
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
            .frame(width: 106, height: 106)
        }
        .buttonStyle(.plain)
        .help(mirror.isRunning ? "Éteindre la caméra" : "Allumer la caméra")
    }
}

// MARK: - Calendrier

private struct CalendarColumn: View {
    @ObservedObject var calendar: CalendarService

    private let today = Calendar.current.startOfDay(for: Date())

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(monthName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                HStack(spacing: 6) {
                    ForEach(week, id: \.self) { day in
                        DayCell(date: day, isToday: day == today)
                    }
                }
            }
            // La barre d'icônes flotte au-dessus du coin supérieur droit :
            // sans cette réserve, les derniers jours passeraient dessous.
            .padding(.trailing, 54)

            Spacer(minLength: 0)

            agenda

            Spacer(minLength: 0)
        }
        .padding(.leading, 16)
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var agenda: some View {
        if !calendar.isAuthorised {
            Button("Activer le calendrier") { calendar.requestAccess() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(.white.opacity(0.1)))
        } else if let event = calendar.next {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(cgColor: event.calendar.cgColor ?? NSColor.systemBlue.cgColor))
                    .frame(width: 3, height: 26)
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title ?? "Sans titre")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(timeRange(event))
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
        } else {
            HStack(spacing: 7) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.35))
                Text("Rien pour aujourd'hui")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
    }

    /// Deux jours en arrière : la semaine reste lisible et aujourd'hui ne se
    /// retrouve pas collé au bord gauche.
    private var week: [Date] {
        let cal = Calendar.current
        guard let start = cal.date(byAdding: .day, value: -2, to: today) else { return [] }
        return (0..<6).compactMap { cal.date(byAdding: .day, value: $0, to: start) }
    }

    private var monthName: String {
        let formatter = DateFormatter()
        formatter.locale = .system
        formatter.dateFormat = "MMMM"
        return formatter.string(from: today)
    }

    private func timeRange(_ event: EKEvent) -> String {
        let formatter = DateFormatter()
        formatter.locale = .system
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        guard let start = event.startDate else { return "" }
        guard let end = event.endDate else { return formatter.string(from: start) }
        return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
    }
}

private struct DayCell: View {
    let date: Date
    let isToday: Bool

    var body: some View {
        VStack(spacing: 3) {
            Text(weekday)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(.white.opacity(isToday ? 0.75 : 0.3))
                .lineLimit(1)
                .fixedSize()
            Text(day)
                .font(.system(size: 15, weight: isToday ? .bold : .regular))
                .foregroundStyle(isToday ? Color.accentColor : .white.opacity(0.45))
        }
        .frame(width: 20)
    }

    private var weekday: String {
        let formatter = DateFormatter()
        formatter.locale = .system
        formatter.dateFormat = isToday ? "EEE" : "EEEEE"
        // « lun. » : le point abrégé fait passer le libellé à la ligne dans
        // une cellule de vingt points.
        return formatter.string(from: date)
            .replacingOccurrences(of: ".", with: "")
            .uppercased()
    }

    private var day: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd"
        return formatter.string(from: date)
    }
}
