import AppKit

/// Exécute des scripts AppleScript hors du fil principal.
///
/// `NSAppleScript` n'est pas réentrant : tous les appels passent par une file
/// sérielle, avec une instance neuve à chaque fois. Et un événement Apple peut
/// bloquer plusieurs dizaines de millisecondes — de quoi faire hoqueter
/// l'animation de l'encoche s'il partait depuis le fil principal.
enum AppleScriptRunner {
    /// Code d'erreur renvoyé quand l'utilisateur a refusé l'automatisation.
    private static let notAuthorized = -1743

    enum Failure: Error {
        /// L'utilisateur a refusé le contrôle de l'app dans Confidentialité et
        /// sécurité. Insister ne sert à rien, il faut le lui dire.
        case notAuthorized
        case failed(String)
    }

    private static let queue = DispatchQueue(
        label: "app.ledgenotch.applescript",
        qos: .utility
    )

    static func run(
        _ source: String,
        completion: @escaping (Result<NSAppleEventDescriptor, Failure>) -> Void
    ) {
        queue.async {
            let result = execute(source)
            DispatchQueue.main.async { completion(result) }
        }
    }

    private static func execute(_ source: String) -> Result<NSAppleEventDescriptor, Failure> {
        guard let script = NSAppleScript(source: source) else {
            return .failure(.failed("script illisible"))
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)

        if let errorInfo {
            let code = errorInfo[NSAppleScript.errorNumber] as? Int ?? 0
            if code == notAuthorized {
                return .failure(.notAuthorized)
            }
            let message = errorInfo[NSAppleScript.errorMessage] as? String
                ?? "erreur \(code)"
            return .failure(.failed(message))
        }

        return .success(descriptor)
    }
}
