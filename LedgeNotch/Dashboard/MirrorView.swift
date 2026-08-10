import AVFoundation
import SwiftUI

/// Aperçu de la caméra frontale, pour se recoiffer avant un appel.
///
/// La caméra ne démarre **que sur un clic**. La démarrer à l'ouverture de
/// l'encoche allumerait la diode verte à chaque passage de souris en haut de
/// l'écran : de quoi croire à une app qui espionne.
@MainActor
final class MirrorSession: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var isDenied = false

    let session = AVCaptureSession()
    private var configured = false

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            launch()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated {
                        guard let self else { return }
                        granted ? self.launch() : (self.isDenied = true)
                    }
                }
            }
        default:
            isDenied = true
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        let session = session
        // `stopRunning` bloque le temps que la caméra s'éteigne : sur le fil
        // principal, l'encoche se figerait en pleine animation de fermeture.
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
        }
    }

    private func launch() {
        isDenied = false
        if !configured {
            configure()
            configured = true
        }
        isRunning = true
        let session = session
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .medium
        if let device = AVCaptureDevice.default(for: .video),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
    }
}

/// Le rendu de la caméra. `AVCaptureVideoPreviewLayer` n'a pas d'équivalent
/// SwiftUI : il faut passer par une couche AppKit.
struct MirrorPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        // Un miroir doit renvoyer l'image inversée, sinon lever la main droite
        // fait bouger celle de gauche.
        preview.connection?.automaticallyAdjustsVideoMirroring = false
        preview.connection?.isVideoMirrored = true
        view.layer = preview

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
