# LedgeNotch

Une étagère dans l'encoche du Mac. Application macOS native, en Swift et SwiftUI.

> État : socle technique. Le curseur fait dépasser l'encoche, un clic l'ouvre,
> avec retour haptique sur le trackpad.
> Les fonctionnalités (étagère à fichiers, lecteur média) restent à écrire.

## Lancer le projet

```bash
open LedgeNotch.xcodeproj
```

Puis ⌘R. Aucune dépendance externe, aucun compte développeur nécessaire :
la cible est signée en ad-hoc (`CODE_SIGN_IDENTITY = "-"`), ce qui suffit
pour exécuter l'app en local.

L'app n'a pas d'icône dans le Dock (`LSUIElement`). Elle se pilote depuis son
icône dans la barre de menus, qui donne accès aux réglages et à « Quitter ».

## Comment ça marche

| Fichier | Rôle |
| --- | --- |
| `Notch/NotchGeometry.swift` | Trouve l'encoche via `safeAreaInsets` et les zones auxiliaires de l'écran. En simule une sur les écrans qui n'en ont pas. |
| `Notch/NotchPanel.swift` | Le `NSPanel` posé au-dessus de la barre de menus. |
| `Notch/NotchHostingView.swift` | Hôte SwiftUI qui ignore la zone de sécurité. |
| `Notch/MouseTracker.swift` | Suit le curseur et les clics à l'échelle du système. |
| `Notch/Haptics.swift` | Retour haptique du trackpad, et ses limites. |
| `Notch/NotchController.swift` | Assemble le tout et décide de l'ouverture. |
| `Notch/NotchShape.swift` | La silhouette, coins supérieurs rentrants compris. |
| `Notch/NotchView.swift` | Le contenu SwiftUI, son animation et l'engrenage. |
| `Settings/Preferences.swift` | Les réglages, conservés dans `UserDefaults`. |
| `Settings/SettingsWindow.swift` | Ouverture de la fenêtre de réglages. |
| `Settings/SettingsView.swift` | La page de réglages. |
| `ClaudeCode/ClaudeEventLog.swift` | Surveille `~/.ledgenotch/events.jsonl`. |
| `ClaudeCode/ClaudeCodeMonitor.swift` | Tient l'état des sessions à jour. |
| `ClaudeCode/ClaudeHooksInstaller.swift` | Écrit les hooks dans `~/.claude/settings.json`. |
| `ClaudeCode/ClaudePanelView.swift` | La liste des sessions dans l'encoche. |

Trois pièges rencontrés, et leur solution, pour mémoire :

1. **macOS repousse les fenêtres sous la barre de menus.** Même sans bordure.
   Il faut surcharger `constrainFrameRect(_:to:)` pour renvoyer le cadre tel quel.
2. **AppKit décale le contenu sous l'encoche** au nom de la zone de sécurité.
   D'où `NotchHostingView`, qui force des `safeAreaInsets` nuls.
3. **Une `NSTrackingArea` ne suffit pas.** Fermée, l'encoche laisse passer les
   clics (`ignoresMouseEvents`) et ne reçoit donc plus rien. Le suivi passe par
   un moniteur d'événements global — qui ne demande, lui, aucune autorisation
   d'accessibilité.
4. **`isFloatingPanel = true` réécrit le niveau de la fenêtre** à `.floating` (3).
   Défini avant lui, le niveau est silencieusement écrasé et la barre de menus
   repasse devant l'encoche. Il faut donc régler `level` en dernier.
5. **La scène `Settings` de SwiftUI n'ouvre rien en `.accessory`.** L'action
   `showSettingsWindow:` est pourtant bien reçue — elle renvoie `true` — mais
   aucune fenêtre n'apparaît tant que l'app n'a pas d'icône dans le Dock. D'où
   le point d'entrée AppKit et la fenêtre construite à la main, qui bascule en
   `.regular` le temps de la consultation.

Pour situer : la barre de menus occupe la couche 24, ses icônes de droite la
couche 25, et les menus déroulants la 101. `CGWindowListCopyWindowInfo` permet
de lire l'ordre d'empilement réel quand quelque chose passe devant sans raison.

## Mise au point

Deux variables d'environnement, à définir dans Xcode via Product → Scheme →
Edit Scheme → Run → Arguments :

| Variable | Effet |
| --- | --- |
| `LEDGENOTCH_FORCE_OPEN=1` | Ouvre l'encoche dès le lancement, pour travailler son contenu sans avoir à survoler puis cliquer. |
| `LEDGENOTCH_FORCE_PANEL=claude` | Choisit l'onglet affiché au lancement. |
| `LEDGENOTCH_OPEN_SETTINGS=1` | Ouvre la fenêtre de réglages au lancement. |
| `LEDGENOTCH_WINDOW_LEVEL=101` | Force le niveau du panneau, pour comparer ce qui passe devant ou derrière. |

## Claude Code

Les hooks de Claude Code écrivent leur charge utile JSON dans
`~/.ledgenotch/events.jsonl`, que LedgeNotch surveille :

```bash
mkdir -p ~/.ledgenotch && { cat; echo; } >> ~/.ledgenotch/events.jsonl
```

Un fichier plutôt qu'un port réseau : aucune alerte du pare-feu, aucun binaire
intermédiaire, les événements s'accumulent même quand LedgeNotch est arrêté, et
on peut le lire à la main quand quelque chose cloche.

Cinq événements suffisent à reconstituer l'état d'une session :

| Événement | Interprétation |
| --- | --- |
| `SessionStart` | La session existe, au repos. |
| `UserPromptSubmit` | Un tour démarre. |
| `Notification` | Bloquée — seulement pour `permission_prompt` et `idle_prompt`. |
| `Stop` | Le tour est terminé. |
| `SessionEnd` | La session disparaît. |

L'installation se fait depuis les réglages, qui fusionnent les entrées dans
`~/.claude/settings.json` sans toucher au reste et en gardant une copie du
fichier d'origine à côté.

## Feuille de route

- [x] Le socle : panneau, géométrie, survol, animation
- [x] Réglages : ouverture au survol, dépassement, retour haptique
- [x] Claude Code : état des sessions, pastille ambiante, alerte
- [ ] Étagère à fichiers (glisser-déposer)
- [ ] Lecteur média — dépend de [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter),
      Apple ayant verrouillé `MediaRemote` depuis macOS 15.4
- [ ] Réglages : écran cible, lancement au démarrage
- [ ] Icône et empaquetage `.dmg`

## Distribution

Le `.dmg` avec glisser-vers-Applications se fabrique gratuitement
(`brew install create-dmg`). En revanche, pour que l'app se lance sans l'alerte
« app endommagée » sur la machine de quelqu'un d'autre, il faut la signer avec
un Developer ID et la faire notariser — ce qui suppose l'adhésion à l'Apple
Developer Program (99 $/an). Décision reportée : ça ne bloque pas le développement.
