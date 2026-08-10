import SwiftUI
import Translation

/// La page traduction : ce qu'on entend à gauche, sa traduction à droite.
struct TranslatePanelView: View {
    @ObservedObject var listener: SpeechListener
    @ObservedObject private var preferences = Preferences.shared

    private var source: TranslationLanguage { preferences.speechSource }
    private var target: TranslationLanguage { preferences.speechTarget }

    var body: some View {
        HStack(spacing: 14) {
            TextColumn(
                language: source,
                text: listener.transcript,
                placeholder: listener.isListening
                    ? "J'écoute…"
                    : "Appuyez sur le micro et parlez.",
                onPick: { preferences.speechSource = $0 }
            )

            microphone

            translation
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

    /// La traduction vit dans sa propre vue : sa configuration est une propriété
    /// stockée que le framework n'expose qu'à partir de macOS 15, et une
    /// propriété ne se déclare pas sous condition de version.
    @ViewBuilder
    private var translation: some View {
        if #available(macOS 15.0, *) {
            TranslatedColumn(
                text: listener.transcript,
                source: source,
                target: target,
                onPick: { preferences.speechTarget = $0 }
            )
        } else {
            TextColumn(
                language: target,
                text: "",
                placeholder: "La traduction demande macOS 15 ou plus récent.",
                onPick: { preferences.speechTarget = $0 }
            )
        }
    }

    private var microphone: some View {
        VStack(spacing: 6) {
            Button {
                listener.toggle(locale: source.locale)
            } label: {
                ZStack {
                    Circle()
                        .fill(listener.isListening
                              ? Color.red.opacity(0.85)
                              : Color.white.opacity(0.1))
                        .frame(width: 46, height: 46)

                    Image(systemName: listener.isListening ? "waveform" : "mic.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
            .help(listener.isListening ? "Arrêter l'écoute" : "Écouter")

            if !listener.transcript.isEmpty {
                Button("Effacer") { listener.clear() }
                    .buttonStyle(.plain)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.35))
            }

            if let problem = listener.problem {
                Text(problem)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.orange.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(width: 82)
            }
        }
        .frame(width: 88)
    }
}

// MARK: - Colonnes

private struct TextColumn: View {
    let language: TranslationLanguage
    let text: String
    let placeholder: String
    let onPick: (TranslationLanguage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LanguageMenu(selection: language, onPick: onPick)

            ScrollView {
                Text(text.isEmpty ? placeholder : text)
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(text.isEmpty ? 0.3 : 0.92))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@available(macOS 15.0, *)
private struct TranslatedColumn: View {
    let text: String
    let source: TranslationLanguage
    let target: TranslationLanguage
    let onPick: (TranslationLanguage) -> Void

    @State private var configuration = TranslationSession.Configuration()
    @State private var output = ""
    @State private var pending = ""
    @State private var debounce: DispatchWorkItem?

    var body: some View {
        TextColumn(
            language: target,
            text: output,
            placeholder: "La traduction s'affiche ici.",
            onPick: onPick
        )
        .translationTask(configuration) { session in
            let phrase = pending
            guard !phrase.isEmpty else { return }
            guard let response = try? await session.translate(phrase) else { return }
            output = response.targetText
        }
        .onAppear { reconfigure() }
        .onChange(of: text) { _, new in schedule(new) }
        .onChange(of: source) { _, _ in reconfigure() }
        .onChange(of: target) { _, _ in reconfigure() }
    }

    private func reconfigure() {
        configuration = TranslationSession.Configuration(
            source: source.language,
            target: target.language
        )
        schedule(text)
    }

    /// La transcription bouge à chaque mot : traduire à chaque syllabe
    /// saturerait le moteur pour un résultat qu'on n'aurait pas le temps de lire.
    private func schedule(_ phrase: String) {
        debounce?.cancel()
        guard !phrase.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""
            return
        }
        let work = DispatchWorkItem {
            MainActor.assumeIsolated {
                pending = phrase
                configuration.invalidate()
            }
        }
        debounce = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }
}

private struct LanguageMenu: View {
    let selection: TranslationLanguage
    let onPick: (TranslationLanguage) -> Void

    var body: some View {
        Menu {
            ForEach(TranslationLanguage.allCases) { language in
                Button {
                    onPick(language)
                } label: {
                    Text("\(language.flag)  \(language.displayName)")
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selection.flag).font(.system(size: 11))
                Text(selection.displayName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.65))
                Image(systemName: "chevron.down")
                    .font(.system(size: 6, weight: .bold))
                    .foregroundStyle(.white.opacity(0.35))
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Capsule().fill(.white.opacity(0.07)))
        }
        // `.borderlessButton` réduisait l'étiquette au seul drapeau et ajoutait
        // son propre chevron à gauche. Le style bouton respecte l'étiquette.
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}
