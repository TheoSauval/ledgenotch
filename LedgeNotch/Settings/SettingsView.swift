import AppKit
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Écran détecté") {
                if let screen = NotchGeometry.preferredScreen() {
                    let geometry = NotchGeometry.detect(on: screen)
                    LabeledContent("Écran", value: screen.localizedName)
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
                }
            }

            Section {
                Text("Les réglages arriveront avec les premières fonctionnalités.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 380)
        .fixedSize(horizontal: false, vertical: true)
    }
}
