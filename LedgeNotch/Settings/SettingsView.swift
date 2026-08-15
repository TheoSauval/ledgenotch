import AppKit
import SwiftUI

/// La fenêtre de réglages, répartie en onglets.
///
/// Un seul formulaire empilait sept sections et débordait de l'écran. Chaque
/// domaine a désormais le sien, et la fenêtre garde une taille fixe : passer
/// d'un onglet à l'autre ne doit pas la faire sauter.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("Général", systemImage: "slider.horizontal.3") }

            MusicSettings()
                .tabItem { Label("Musique", systemImage: "music.note") }

            WeatherSettings()
                .tabItem { Label("Météo", systemImage: "cloud.sun") }

            PrompterSettings()
                .tabItem { Label("Prompteur", systemImage: "text.alignleft") }

            ClaudeSettings()
                .tabItem { Label("Claude Code", systemImage: "terminal") }

            ScreenSettings()
                .tabItem { Label("Écran", systemImage: "display") }
        }
        .frame(width: 480, height: 380)
    }
}

// MARK: - Général

private struct GeneralSettings: View {
    @ObservedObject private var preferences = Preferences.shared

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
        }
        .formStyle(.grouped)
    }
}

// MARK: - Musique

private struct MusicSettings: View {
    @State private var players: [MusicApp] = MusicApp.available

    var body: some View {
        Form {
            Section("Lecteurs détectés") {
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
            }

            Section("YouTube") {
                Text("Pour commander une vidéo — et pas seulement l'afficher — il faut autoriser « JavaScript depuis les Apple Events » : dans Chrome via Affichage → Développeur, dans Safari via Développement après avoir activé les fonctionnalités pour développeurs web.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { players = MusicApp.available }
    }
}

// MARK: - Météo

private struct WeatherSettings: View {
    @ObservedObject private var preferences = Preferences.shared

    var body: some View {
        Form {
            Section("Emplacement") {
                TextField("Ville", text: $preferences.weatherCity, prompt: Text("Ma position"))
                Text("Laissez vide pour utiliser votre position. Indiquez une ville si vous préférez ne pas activer la localisation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Source") {
                Text("Les relevés viennent d'Open-Meteo, sans clé ni compte. WeatherKit d'Apple supposerait l'adhésion au programme développeur.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Prompteur

private struct PrompterSettings: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var importError: String?

    var body: some View {
        Form {
            Section("Texte") {
                HStack {
                    Button("Importer un document…") { importScript() }
                    Spacer()
                    if !preferences.prompterScript.isEmpty {
                        Button("Effacer") { preferences.prompterScript = "" }
                    }
                }

                Text("Word, RTF, PDF, OpenDocument, Markdown ou texte brut. Seul le texte est repris, la mise en forme est écartée.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let importError {
                    Text(importError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                TextEditor(text: $preferences.prompterScript)
                    .font(.system(size: 12))
                    .frame(height: 92)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Section("Défilement") {
                VStack(alignment: .leading, spacing: 4) {
                    Slider(
                        value: $preferences.prompterSpeed,
                        in: Preferences.prompterSpeedRange,
                        step: 10
                    ) {
                        Text("Vitesse")
                    } minimumValueLabel: {
                        Text("80")
                    } maximumValueLabel: {
                        Text("220")
                    }
                    Text("\(Int(preferences.prompterSpeed)) mots par minute, quand le prompteur n'écoute pas la voix.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func importScript() {
        importError = nil
        do {
            if let text = try ScriptImporter.pick(), !text.isEmpty {
                preferences.prompterScript = text
            }
        } catch {
            importError = error.localizedDescription
        }
    }
}

// MARK: - Claude Code

private struct ClaudeSettings: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var hooksInstalled = ClaudeHooksInstaller.isInstalled
    @State private var hooksError: String?

    var body: some View {
        Form {
            Section("Hooks") {
                HStack {
                    Image(systemName: hooksInstalled
                          ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(hooksInstalled ? .green : .orange)
                    Text(hooksInstalled ? "Hooks installés" : "Hooks non installés")
                    Spacer()
                    Button(hooksInstalled ? "Retirer" : "Installer") { toggleHooks() }
                }

                Text("LedgeNotch ajoute cinq hooks à ~/.claude/settings.json pour connaître l'état de vos sessions. Une copie du fichier est conservée à côté avant toute modification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let hooksError {
                    Text(hooksError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Alerte") {
                Toggle("Signaler dans l'encoche", isOn: $preferences.alertOnClaudeEvents)
                Text("L'encoche dépasse brièvement quand une session se bloque sur une question ou vient de terminer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .onAppear { hooksInstalled = ClaudeHooksInstaller.isInstalled }
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
}

// MARK: - Écran

private struct ScreenSettings: View {
    @ObservedObject private var preferences = Preferences.shared
    @State private var geometry: NotchGeometry?

    var body: some View {
        Form {
            Section("Écran détecté") {
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
                    Button("Tout réinitialiser") { preferences.resetToDefaults() }
                    Spacer()
                    Text("Version \(version)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
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
