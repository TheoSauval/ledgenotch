import AppKit

/// Retour haptique du trackpad.
///
/// Trois limites à garder en tête, elles expliquent la plupart des « ça ne marche
/// pas » :
/// - il faut un trackpad Force Touch (2015 et après) ; une souris ne vibre pas ;
/// - **un doigt doit reposer sur le trackpad au moment du retour**. Cliquer puis
///   lever le doigt aussitôt ne laisse rien sentir ;
/// - le réglage système « Retour du Force Touch » peut le désactiver globalement.
@MainActor
enum Haptics {
    /// Ouverture : le cran net d'un mécanisme qui s'enclenche.
    static func open() {
        perform(.levelChange)
    }

    /// Fermeture : plus discret, pour ne pas mettre les deux sur le même plan.
    static func close() {
        perform(.generic)
    }

    /// Survol : le pattern le plus léger de la palette, une simple confirmation
    /// que l'encoche a réagi.
    static func peek() {
        perform(.alignment)
    }

    private static func perform(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
        guard Preferences.shared.hapticsEnabled else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(
            pattern,
            performanceTime: .now
        )
    }
}
