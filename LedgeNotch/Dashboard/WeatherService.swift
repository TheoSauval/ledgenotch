import CoreLocation
import SwiftUI

struct WeatherHour: Equatable, Identifiable {
    let date: Date
    let temperature: Double
    let code: Int

    var id: Date { date }
}

struct WeatherReport: Equatable {
    let place: String
    var hours: [WeatherHour] = []
    let temperature: Double
    let high: Double
    let low: Double
    let code: Int
    let isDay: Bool

    /// Les codes WMO renvoyés par Open-Meteo, ramenés à une icône du système.
    var symbolName: String {
        switch code {
        case 0: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    var summary: String {
        switch code {
        case 0: return "Ciel dégagé"
        case 1: return "Peu nuageux"
        case 2: return "Partiellement nuageux"
        case 3: return "Couvert"
        case 45, 48: return "Brouillard"
        case 51, 53, 55: return "Bruine"
        case 56, 57: return "Bruine verglaçante"
        case 61, 63, 65: return "Pluie"
        case 66, 67: return "Pluie verglaçante"
        case 71, 73, 75, 77: return "Neige"
        case 80, 81, 82: return "Averses"
        case 85, 86: return "Averses de neige"
        case 95: return "Orage"
        case 96, 99: return "Orage et grêle"
        default: return "—"
        }
    }
}

/// La météo du lieu, via Open-Meteo.
///
/// Open-Meteo plutôt que WeatherKit : ce dernier suppose l'adhésion à l'Apple
/// Developer Program, que ce projet a justement choisi de ne pas payer pour le
/// moment. Open-Meteo ne demande ni clé ni inscription.
@MainActor
final class WeatherService: NSObject, ObservableObject {
    @Published private(set) var report: WeatherReport?
    @Published private(set) var status: CLAuthorizationStatus = .notDetermined
    @Published private(set) var failed = false

    private let manager = CLLocationManager()
    private let preferences = Preferences.shared
    private var timer: Timer?

    /// Un quart d'heure : la météo ne change pas plus vite, et Open-Meteo elle-même
    /// ne rafraîchit ses relevés que toutes les quinze minutes.
    private let interval: TimeInterval = 900

    var usesManualCity: Bool { !preferences.weatherCity.isEmpty }
    var needsLocation: Bool {
        !usesManualCity && (status == .notDetermined || status == .denied || status == .restricted)
    }

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        status = manager.authorizationStatus
    }

    func start() {
        refresh()
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// L'autorisation n'est jamais demandée d'office, comme pour le calendrier :
    /// une alerte système déclenchée par un simple survol serait déplacée.
    func requestLocation() {
        manager.requestWhenInUseAuthorization()
    }

    func refresh() {
        if usesManualCity {
            geocode(preferences.weatherCity)
            return
        }
        status = manager.authorizationStatus
        guard status == .authorizedAlways || status == .authorized else { return }
        manager.requestLocation()
    }

    // MARK: - Requêtes

    private func geocode(_ city: String) {
        guard
            let encoded = city.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "https://geocoding-api.open-meteo.com/v1/search?name=\(encoded)&count=1&language=fr&format=json")
        else { return }

        fetch(url, as: GeocodingResponse.self) { [weak self] response in
            guard let place = response?.results?.first else {
                self?.failed = true
                return
            }
            self?.load(
                latitude: place.latitude,
                longitude: place.longitude,
                place: place.name
            )
        }
    }

    private func load(latitude: Double, longitude: Double, place: String) {
        guard let url = URL(string:
            "https://api.open-meteo.com/v1/forecast"
            + "?latitude=\(latitude)&longitude=\(longitude)"
            + "&current=temperature_2m,weather_code,is_day"
            + "&daily=temperature_2m_max,temperature_2m_min"
            + "&hourly=temperature_2m,weather_code&forecast_hours=48"
            + "&timezone=auto&forecast_days=1"
        ) else { return }

        fetch(url, as: ForecastResponse.self) { [weak self] response in
            guard let response else {
                self?.failed = true
                return
            }
            self?.failed = false
            self?.report = WeatherReport(
                place: place,
                hours: Self.hours(from: response),
                temperature: response.current.temperature,
                high: response.daily.highs.first ?? response.current.temperature,
                low: response.daily.lows.first ?? response.current.temperature,
                code: response.current.code,
                isDay: response.current.isDay == 1
            )
        }
    }

    /// Deux jours de créneaux, dont on écarte ceux déjà passés. La bande
    /// horaire de la page défile : mieux vaut avoir de la matière à faire
    /// glisser que de s'arrêter net au bout de sept heures.
    private static func hours(from response: ForecastResponse) -> [WeatherHour] {
        guard let hourly = response.hourly else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        formatter.timeZone = .current

        let start = Date().addingTimeInterval(-1800)
        return zip(zip(hourly.time, hourly.temperature), hourly.code)
            .compactMap { pair, code -> WeatherHour? in
                guard let date = formatter.date(from: pair.0), date > start else { return nil }
                return WeatherHour(date: date, temperature: pair.1, code: code)
            }
            .map { $0 }
    }

    private func fetch<T: Decodable>(
        _ url: URL,
        as type: T.Type,
        completion: @escaping (T?) -> Void
    ) {
        URLSession.shared.dataTask(with: url) { data, _, _ in
            // Pas de `convertFromSnakeCase` : son algorithme trébuche sur les
            // chiffres, et `temperature_2m` ne devient pas `temperature2m`.
            // Les clés sont donc déclarées à la main.
            let decoded = data.flatMap { try? JSONDecoder().decode(T.self, from: $0) }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { completion(decoded) }
            }
        }.resume()
    }
}

extension WeatherService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        MainActor.assumeIsolated {
            self.status = manager.authorizationStatus
            self.refresh()
        }
    }

    nonisolated func locationManager(
        _ manager: CLLocationManager,
        didUpdateLocations locations: [CLLocation]
    ) {
        guard let location = locations.last else { return }
        MainActor.assumeIsolated {
            // Le nom de la ville demande un géocodage inverse, qui ne réclame
            // aucune autorisation supplémentaire.
            CLGeocoder().reverseGeocodeLocation(location) { [weak self] places, _ in
                MainActor.assumeIsolated {
                    self?.load(
                        latitude: location.coordinate.latitude,
                        longitude: location.coordinate.longitude,
                        place: places?.first?.locality ?? "Ma position"
                    )
                }
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        MainActor.assumeIsolated { self.failed = true }
    }
}

// MARK: - Réponses de l'API

private struct ForecastResponse: Decodable {
    struct Current: Decodable {
        let temperature: Double
        let code: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature = "temperature_2m"
            case code = "weather_code"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let highs: [Double]
        let lows: [Double]

        enum CodingKeys: String, CodingKey {
            case highs = "temperature_2m_max"
            case lows = "temperature_2m_min"
        }
    }

    struct Hourly: Decodable {
        let time: [String]
        let temperature: [Double]
        let code: [Int]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature = "temperature_2m"
            case code = "weather_code"
        }
    }

    let current: Current
    let daily: Daily
    let hourly: Hourly?
}

private struct GeocodingResponse: Decodable {
    struct Place: Decodable {
        let name: String
        let latitude: Double
        let longitude: Double
    }
    let results: [Place]?
}
