import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var geometry: NotchGeometry?

    var body: some View {
        Form {
            Section("Ouverture") {
                Toggle("Ouvrir au survol", isOn: $preferences.openOnHover)
                Text(preferences.openOnHover
                     ? "L'encoche s'ouvre dès que le curseur l'atteint."
                     : "Le curseur fait dépasser l'encoche ; un clic l'ouvre.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 4) {
                    Slider(
                        value: $preferences.peekAmount,
                        in: Preferences.peekRange,
                        step: 5
                    ) {
                        Text("Dépassement au survol")
                    } minimumValueLabel: {
                        Text("0")
                    } maximumValueLabel: {
                        Text("80")
                    }
                    Text("\(Int(preferences.peekAmount)) points. L'effet est visible immédiatement.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .disabled(preferences.openOnHover)
                .opacity(preferences.openOnHover ? 0.4 : 1)
            }

            Section("Retour haptique") {
                Toggle("Vibrer le trackpad", isOn: $preferences.hapticsEnabled)
                Text("Demande un trackpad Force Touch, et un doigt posé dessus au moment précis du retour — sinon on ne sent rien. Le réglage système « Retour du Force Touch » doit aussi être actif.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Écran") {
                if let geometry {
                    LabeledContent("Écran", value: geometry.screen.localizedName)
                    LabeledContent(
                        "Encoche",
                        value: geometry.isPhysical ? "physique" : "simulée"
                    )
                    LabeledContent(
                        "Dimensions",
                        value: String(
                            format: "%.0f × %.0f pt",
                            geometry.notchRect.width,
                            geometry.notchRect.height
                        )
                    )
                } else {
                    Text("Aucun écran détecté.")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                HStack {
                    Button("Réinitialiser") {
                        preferences.resetToDefaults()
                    }
                    Spacer()
                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear(perform: refreshGeometry)
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification
            )
        ) { _ in
            refreshGeometry()
        }
    }

    private func refreshGeometry() {
        geometry = NotchGeometry.preferredScreen().map(NotchGeometry.detect(on:))
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
