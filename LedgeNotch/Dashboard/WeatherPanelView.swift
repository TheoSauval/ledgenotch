import SwiftUI

/// La page météo de l'encoche.
struct WeatherPanelView: View {
    @ObservedObject var weather: WeatherService

    var body: some View {
        if let report = weather.report {
            forecast(report)
        } else if weather.needsLocation {
            invitation
        } else {
            placeholder
        }
    }

    // MARK: - Prévisions

    private func forecast(_ report: WeatherReport) -> some View {
        HStack(spacing: 22) {
            current(report)

            if !report.hours.isEmpty {
                Divider().overlay(.white.opacity(0.09)).frame(height: 88)

                // Deux jours de prévisions dans la largeur d'une encoche : la
                // bande défile au trackpad, deux doigts vers la gauche.
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(report.hours) { hour in
                            HourCell(hour: hour)
                        }
                    }
                    .padding(.trailing, 8)
                }
                .scrollIndicators(.hidden)
                // L'estompage du bord droit indique qu'il reste des heures
                // au-delà, ce qu'une bande coupée net ne dirait pas.
                .mask(
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0),
                            .init(color: .black, location: 0.92),
                            .init(color: .clear, location: 1),
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            }
        }
        .padding(.leading, 26)
    }

    private func current(_ report: WeatherReport) -> some View {
        HStack(spacing: 16) {
            Image(systemName: report.symbolName)
                .font(.system(size: 44))
                .symbolRenderingMode(.multicolor)
                .frame(width: 54)

            VStack(alignment: .leading, spacing: 2) {
                Text(temperature(report.temperature))
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(.white)

                Text(report.summary)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)

                HStack(spacing: 9) {
                    Label(temperature(report.high), systemImage: "arrow.up")
                    Label(temperature(report.low), systemImage: "arrow.down")
                    Text(report.place)
                        .foregroundStyle(.white.opacity(0.3))
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.4))
                .padding(.top, 2)
            }
        }
    }

    // MARK: - États d'attente

    private var invitation: some View {
        VStack(spacing: 9) {
            Image(systemName: "location.slash")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(.white.opacity(0.35))

            Text("Où êtes-vous ?")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)

            Text("La météo a besoin de votre position, ou d'une ville indiquée dans les réglages.")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 60)

            Button("Activer la localisation") { weather.requestLocation() }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Capsule().fill(.white.opacity(0.12)))
        }
    }

    private var placeholder: some View {
        VStack(spacing: 7) {
            Image(systemName: weather.failed ? "cloud.slash" : "cloud")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
            Text(weather.failed ? "Météo indisponible" : "Relevé en cours…")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
    }

    private func temperature(_ value: Double) -> String {
        String(format: "%.0f°", value.rounded())
    }
}

private struct HourCell: View {
    let hour: WeatherHour

    var body: some View {
        VStack(spacing: 6) {
            Text(label)
                .font(.system(size: 10, weight: isDayStart ? .bold : .medium))
                .foregroundStyle(.white.opacity(isDayStart ? 0.65 : 0.4))
                .lineLimit(1)
                .fixedSize()

            Image(systemName: report.symbolName)
                .font(.system(size: 15))
                .symbolRenderingMode(.multicolor)

            Text(String(format: "%.0f°", hour.temperature.rounded()))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(width: 34)
    }

    /// On réutilise la mise en forme du relevé courant plutôt que de dupliquer
    /// la table des codes WMO.
    private var report: WeatherReport {
        WeatherReport(
            place: "",
            temperature: hour.temperature,
            high: 0,
            low: 0,
            code: hour.code,
            isDay: isDaylight
        )
    }

    /// Le jour et la nuit ne sont pas fournis créneau par créneau : une règle
    /// simple suffit à choisir entre le soleil et la lune.
    private var isDaylight: Bool {
        let value = Calendar.current.component(.hour, from: hour.date)
        return value >= 7 && value < 21
    }

    /// Minuit marque le passage au lendemain : afficher « 00h » n'apprendrait
    /// rien, le nom du jour situe la suite de la bande.
    private var isDayStart: Bool {
        Calendar.current.component(.hour, from: hour.date) == 0
    }

    private var label: String {
        let formatter = DateFormatter()
        formatter.locale = .system
        if isDayStart {
            formatter.dateFormat = "EEE"
            return formatter.string(from: hour.date)
                .replacingOccurrences(of: ".", with: "")
                .capitalized
        }
        formatter.dateFormat = "HH"
        return formatter.string(from: hour.date) + "h"
    }
}
