import AppKit

/// Lit et pilote une vidéo YouTube ouverte dans un navigateur.
///
/// Deux niveaux, volontairement séparés :
///
/// - **Le titre et la vignette** se déduisent du titre de l'onglet et de son
///   adresse. Aucun réglage particulier, ça marche toujours.
/// - **L'état de lecture et les commandes** demandent d'exécuter du JavaScript
///   dans la page, ce que les navigateurs refusent par défaut. Le réglage est
///   masqué et l'utilisateur doit l'activer lui-même.
///
/// D'où cette séparation : on affiche ce qu'on peut sans rien demander, et on
/// n'exige un réglage que pour ce qui l'impose vraiment.
enum YouTubeBridge {
    struct Tab {
        let browser: Browser
        let title: String
        let videoID: String?
    }

    /// Récupère titre et adresse en deux requêtes plutôt qu'en parcourant les
    /// onglets un par un : chaque accès à une propriété est un événement Apple,
    /// et une fenêtre de cinquante onglets rendrait le sondage interminable.
    private static func findTabScript(for browser: Browser) -> String {
        let titleProperty = browser.isChromium ? "title" : "name"
        return """
        tell application "\(browser.scriptingName)"
            try
                set sep to (ASCII character 31)
                set allURLs to URL of every tab of every window
                set allTitles to \(titleProperty) of every tab of every window
                repeat with i from 1 to count of allURLs
                    set windowURLs to item i of allURLs
                    set windowTitles to item i of allTitles
                    repeat with j from 1 to count of windowURLs
                        set theURL to item j of windowURLs
                        if theURL contains "youtube.com/watch" then
                            return (item j of windowTitles) & sep & theURL
                        end if
                    end repeat
                end repeat
                return ""
            on error
                return ""
            end try
        end tell
        """
    }

    private static func javaScriptScript(for browser: Browser, code: String) -> String {
        let escaped = code
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let invocation = browser.isChromium
            ? "return (execute t javascript \"\(escaped)\") as text"
            : "return (do JavaScript \"\(escaped)\" in t) as text"

        return """
        tell application "\(browser.scriptingName)"
            repeat with w in windows
                repeat with t in tabs of w
                    if (URL of t) contains "youtube.com/watch" then
                        \(invocation)
                    end if
                end repeat
            end repeat
            return ""
        end tell
        """
    }

    // MARK: - Lecture

    static func findTab(completion: @escaping (Tab?) -> Void) {
        search(Browser.running, completion: completion)
    }

    private static func search(_ browsers: [Browser], completion: @escaping (Tab?) -> Void) {
        guard let browser = browsers.first else {
            completion(nil)
            return
        }
        AppleScriptRunner.run(findTabScript(for: browser)) { result in
            if case .success(let descriptor) = result,
               let raw = descriptor.stringValue,
               !raw.isEmpty {
                let parts = raw.components(separatedBy: MusicScripts.separator)
                if parts.count >= 2 {
                    completion(
                        Tab(
                            browser: browser,
                            title: cleanTitle(parts[0]),
                            videoID: videoID(from: parts[1])
                        )
                    )
                    return
                }
            }
            search(Array(browsers.dropFirst()), completion: completion)
        }
    }

    /// `playing`, `paused`, ou `nil` quand le navigateur refuse le JavaScript.
    static func playbackState(in browser: Browser, completion: @escaping (Bool?) -> Void) {
        let code = "(function(){var v=document.querySelector('video');"
            + "return v?(v.paused?'paused':'playing'):'';})()"
        AppleScriptRunner.run(javaScriptScript(for: browser, code: code)) { result in
            guard case .success(let descriptor) = result,
                  let value = descriptor.stringValue,
                  !value.isEmpty
            else {
                completion(nil)
                return
            }
            completion(value == "playing")
        }
    }

    // MARK: - Commandes

    static func command(_ command: MusicScripts.Command, in browser: Browser) {
        let code: String
        switch command {
        case .playPause:
            code = "(function(){var v=document.querySelector('video');"
                + "if(v){v.paused?v.play():v.pause();}return '';})()"
        case .next:
            code = "(function(){var b=document.querySelector('.ytp-next-button');"
                + "if(b)b.click();return '';})()"
        case .previous:
            // YouTube masque souvent le bouton précédent : à défaut, on revient
            // au début de la vidéo, ce que fait aussi un lecteur classique.
            code = "(function(){var b=document.querySelector('.ytp-prev-button');"
                + "if(b&&b.offsetParent){b.click();}else{var v=document.querySelector('video');"
                + "if(v)v.currentTime=0;}return '';})()"
        }
        AppleScriptRunner.run(javaScriptScript(for: browser, code: code)) { _ in }
    }

    // MARK: - Analyse

    /// Les titres d'onglet YouTube arrivent sous la forme `(3) Titre - YouTube`,
    /// le nombre entre parenthèses étant les notifications non lues.
    private static func cleanTitle(_ raw: String) -> String {
        var title = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.hasPrefix("("), let close = title.firstIndex(of: ")") {
            title = String(title[title.index(after: close)...])
                .trimmingCharacters(in: .whitespaces)
        }
        for suffix in [" - YouTube", " — YouTube"] where title.hasSuffix(suffix) {
            title = String(title.dropLast(suffix.count))
        }
        return title.trimmingCharacters(in: .whitespaces)
    }

    private static func videoID(from address: String) -> String? {
        guard
            let components = URLComponents(string: address),
            let value = components.queryItems?.first(where: { $0.name == "v" })?.value,
            !value.isEmpty
        else { return nil }
        return value
    }

    /// La vignette se sert directement chez YouTube, sans clé ni API.
    static func thumbnailURL(for videoID: String) -> URL? {
        URL(string: "https://img.youtube.com/vi/\(videoID)/mqdefault.jpg")
    }
}
