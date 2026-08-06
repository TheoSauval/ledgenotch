# LedgeNotch

Une étagère dans l'encoche du Mac. Application macOS native, en Swift et SwiftUI.

> État : socle technique. L'encoche s'ouvre et se referme au survol.
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
| `Notch/MouseTracker.swift` | Suit le curseur à l'échelle du système. |
| `Notch/NotchController.swift` | Assemble le tout et décide de l'ouverture. |
| `Notch/NotchShape.swift` | La silhouette, coins supérieurs rentrants compris. |
| `Notch/NotchView.swift` | Le contenu SwiftUI et son animation. |

Trois pièges rencontrés, et leur solution, pour mémoire :

1. **macOS repousse les fenêtres sous la barre de menus.** Même sans bordure.
   Il faut surcharger `constrainFrameRect(_:to:)` pour renvoyer le cadre tel quel.
2. **AppKit décale le contenu sous l'encoche** au nom de la zone de sécurité.
   D'où `NotchHostingView`, qui force des `safeAreaInsets` nuls.
3. **Une `NSTrackingArea` ne suffit pas.** Fermée, l'encoche laisse passer les
   clics (`ignoresMouseEvents`) et ne reçoit donc plus rien. Le suivi passe par
   un moniteur d'événements global — qui ne demande, lui, aucune autorisation
   d'accessibilité.

## Feuille de route

- [x] Le socle : panneau, géométrie, survol, animation
- [ ] Étagère à fichiers (glisser-déposer)
- [ ] Lecteur média — dépend de [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter),
      Apple ayant verrouillé `MediaRemote` depuis macOS 15.4
- [ ] Réglages : écran cible, taille ouverte, lancement au démarrage
- [ ] Icône et empaquetage `.dmg`

## Distribution

Le `.dmg` avec glisser-vers-Applications se fabrique gratuitement
(`brew install create-dmg`). En revanche, pour que l'app se lance sans l'alerte
« app endommagée » sur la machine de quelqu'un d'autre, il faut la signer avec
un Developer ID et la faire notariser — ce qui suppose l'adhésion à l'Apple
Developer Program (99 $/an). Décision reportée : ça ne bloque pas le développement.
