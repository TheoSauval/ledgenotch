import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var geometry: NotchGeometry?
    @State private var hooksInstalled = ClaudeHooksInstaller.isInstalled
    @State private var hooksError: String?
    @State private var players: [MusicApp] = MusicApp.available

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

            Section("Musique") {
                if players.isEmpty {
                    Text("Aucun lecteur ouvert.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(players) { player in
                        LabeledContent(player.displayName, value: "ouvert")
                    }
                }

                Text("La source se choisit dans l'encoche, onglet musique. Apple Music et Spotify sont pilotés par AppleScript ; YouTube passe par l'onglet du navigateur.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Pour commander une vidéo YouTube — et pas seulement l'afficher — il faut autoriser « JavaScript depuis les Apple Events » : dans Chrome via Affichage → Développeur, dans Safari via Développement après avoir activé les fonctionnalités pour développeurs web.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Claude Code") {
                HStack {
                    Image(systemName: hooksInstalled
                          ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(hooksInstalled ? .green : .orange)
                    Text(hooksInstalled ? "Hooks installés" : "Hooks non installés")
                    Spacer()
                    Button(hooksInstalled ? "Retirer" : "Installer") {
                        toggleHooks()
                    }
                }

                Text("LedgeNotch ajoute cinq hooks à ~/.claude/settings.json pour connaître l'état de tes sessions. Une copie du fichier est conservée à côté avant toute modification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let hooksError {
                    Text(hooksError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("Signaler dans l'encoche", isOn: $preferences.alertOnClaudeEvents)
                Text("L'encoche dépasse brièvement quand une session se bloque sur une question ou vient de terminer.")
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
        .onAppear {
            refreshGeometry()
            players = MusicApp.available
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for: NSApplication.didChangeScreenParametersNotification
            )
        ) { _ in
            refreshGeometry()
        }
    }

    private func toggleHooks() {
        hooksError = nil
        do {
            if hooksInstalled {
                try ClaudeHooksInstaller.uninstall()
            } else {
                try ClaudeHooksInstaller.install()
            }
        } catch {
            hooksError = error.localizedDescription
        }
        hooksInstalled = ClaudeHooksInstaller.isInstalled
    }

    private func refreshGeometry() {
        geometry = NotchGeometry.preferredScreen().map(NotchGeometry.detect(on:))
    }

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }
}
