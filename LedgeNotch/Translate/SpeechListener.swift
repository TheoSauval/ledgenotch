import AVFoundation
import Speech
import SwiftUI

/// Transcrit en direct ce qui arrive au micro.
///
/// Le micro ne s'ouvre **que sur un clic**, comme la caméra du miroir : une app
/// qui écoute dès qu'on effleure le haut de l'écran serait inacceptable.
@MainActor
final class SpeechListener: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var isListening = false
    @Published private(set) var problem: String?

    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    /// Ce qui a déjà été validé par le moteur. Les résultats partiels remplacent
    /// la fin de la phrase en cours, mais ne doivent pas effacer les précédentes.
    private var settled = ""

    func toggle(locale: Locale) {
        isListening ? stop() : start(locale: locale)
    }

    func start(locale: Locale) {
        problem = nil

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard status == .authorized else {
                        self.problem = "Reconnaissance vocale refusée."
                        return
                    }
                    self.requestMicrophone(locale: locale)
                }
            }
        }
    }

    private func requestMicrophone(locale: Locale) {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    guard granted else {
                        self.problem = "Micro refusé."
                        return
                    }
                    self.launch(locale: locale)
                }
            }
        }
    }

    private func launch(locale: Locale) {
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            problem = "Langue non prise en charge sur cette machine."
            return
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        // Reconnaissance locale quand la machine sait le faire : rien ne part
        // chez Apple, et ça marche sans réseau.
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            problem = "Le micro n'a pas démarré."
            return
        }

        settled = transcript.isEmpty ? "" : transcript + " "
        isListening = true
        listen(with: recognizer, request: request, locale: locale)
    }

    private func listen(
        with recognizer: SFSpeechRecognizer,
        request: SFSpeechAudioBufferRecognitionRequest,
        locale: Locale
    ) {
        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            MainActor.assumeIsolated {
                guard let self else { return }

                if let result {
                    self.transcript = self.settled + result.bestTranscription.formattedString
                    if result.isFinal {
                        // Une tâche s'arrête d'elle-même au bout d'une minute :
                        // sans relance, l'écoute cesserait en pleine phrase.
                        self.settled = self.transcript + " "
                        self.restart(locale: locale)
                    }
                }

                if error != nil, self.isListening {
                    self.restart(locale: locale)
                }
            }
        }
    }

    private func restart(locale: Locale) {
        guard isListening else { return }
        teardownRecognition()
        launch(locale: locale)
    }

    func stop() {
        isListening = false
        teardownRecognition()
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
    }

    /// Injecte une phrase sans passer par le micro, pour vérifier la traduction
    /// sans avoir à parler.
    func preload(_ phrase: String) {
        settled = phrase + " "
        transcript = phrase
    }

    func clear() {
        transcript = ""
        settled = ""
    }

    private func teardownRecognition() {
        task?.cancel()
        task = nil
        request?.endAudio()
        request = nil
    }
}
