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
| `ClaudeCode/ClaudeEventLog.swift` | Surveille `~/.ledgenotch/events/claude.jsonl`. |
| `ClaudeCode/ClaudeCodeMonitor.swift` | Tient l'état des sessions à jour. |
| `ClaudeCode/ClaudeHooksInstaller.swift` | Écrit les hooks dans `~/.claude/settings.json`. |
| `ClaudeCode/ClaudePanelView.swift` | La liste des sessions dans l'encoche. |
| `Music/MusicApp.swift` | Les trois sources, et leur disponibilité. |
| `Music/Browser.swift` | Les navigateurs pilotables, Safari et la famille Chromium. |
| `Music/YouTubeBridge.swift` | Lit et commande une vidéo dans un onglet. |
| `Music/MusicScripts.swift` | Les scripts AppleScript. |
| `Music/AppleScriptRunner.swift` | Exécution hors du fil principal. |
| `Music/MusicController.swift` | Sondage, pochettes et commandes. |
| `Music/SoundBars.swift` | L'égaliseur animé de l'encoche repliée. |
| `Dashboard/HomeDashboardView.swift` | Les trois colonnes de la vue par défaut. |
| `Dashboard/MirrorView.swift` | L'aperçu caméra, qui ne démarre que sur un clic. |
| `Dashboard/CalendarService.swift` | Les rendez-vous du jour, via EventKit. |
| `Dashboard/WeatherService.swift` | La météo, via Open-Meteo. |
| `Dashboard/WeatherPanelView.swift` | La page météo et ses prochaines heures. |
| `Dashboard/SystemLocale.swift` | La langue du Mac, et non celle de l'app. |
| `Translate/SpeechListener.swift` | La transcription du micro, en direct. |
| `Translate/TranslatePanelView.swift` | La page traduction et ses deux colonnes. |
| `Translate/TranslationLanguage.swift` | Les langues proposées. |
| `DeepWork/DeepWorkTimer.swift` | Le minuteur de séance et le compte du jour. |
| `DeepWork/DeepWorkPanelView.swift` | La page concentration et sa pastille. |
| `Prompter/PrompterEngine.swift` | Le découpage du texte et le recalage sur la voix. |
| `Prompter/PrompterPanelView.swift` | La page prompteur. |

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
5. **Il n'y a pas d'écran derrière l'encoche.** Entre `auxiliaryTopLeftArea`
   et `auxiliaryTopRightArea` se trouve le boîtier physique de la caméra : ce
   qu'on y dessine part dans le vide. Le piège est qu'une capture d'écran lit
   la mémoire vidéo, qui contient bien cette zone — le contenu invisible sur la
   dalle apparaît donc parfaitement sur la capture. D'où l'élargissement de
   l'encoche repliée dès qu'elle a quelque chose à montrer, pour placer ce
   contenu de part et d'autre du boîtier.
6. **La scène `Settings` de SwiftUI n'ouvre rien en `.accessory`.** L'action
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
| `LEDGENOTCH_FORCE_PHASE=peek` | Fige l'encoche dans un état : `closed`, `peek` ou `open`. Le survol est le seul qu'on ne peut pas observer autrement — il disparaît dès qu'on éloigne le curseur pour regarder. |
| `LEDGENOTCH_FORCE_PANEL=claude` | Choisit l'onglet affiché au lancement : `home`, `music` ou `claude`. |
| `LEDGENOTCH_DEEPWORK=1` | Démarre une séance au lancement, pour observer le décompte sur l'encoche repliée sans attendre. |
| `LEDGENOTCH_OPEN_SETTINGS=1` | Ouvre la fenêtre de réglages au lancement. |
| `LEDGENOTCH_WINDOW_LEVEL=101` | Force le niveau du panneau, pour comparer ce qui passe devant ou derrière. |

## Claude Code

Les hooks de Claude Code écrivent leur charge utile JSON dans
`~/.ledgenotch/events/claude.jsonl`, que LedgeNotch surveille :

```bash
mkdir -p ~/.ledgenotch/events && { cat; echo; } >> ~/.ledgenotch/events/claude.jsonl
```

Un fichier plutôt qu'un port réseau : aucune alerte du pare-feu, aucun binaire
intermédiaire, les événements s'accumulent même quand LedgeNotch est arrêté, et
on peut le lire à la main quand quelque chose cloche.

Un dossier plutôt qu'un fichier unique, avec un fichier par agent. Codex CLI,
Gemini CLI et OpenCode savent eux aussi signaler leurs événements, chacun dans
son format ; déduire l'origine du nom du fichier évitera de fabriquer du JSON
en ligne de commande le jour où on en branche un second. Les adaptateurs
viendront à ce moment-là — pour un seul agent, ce serait de la structure pour
rien. Seul le chemin devait être arrêté tôt : il part dans les hooks installés
chez l'utilisateur, et le changer ensuite les laisserait écrire dans le vide
sans la moindre erreur visible.

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

## Musique

Apple Music et Spotify sont pilotés par **AppleScript**, pas par `MediaRemote` :
Apple a verrouillé ce framework privé depuis macOS 15.4 et les contournements
cassent à chaque mise à jour du système. On perd l'audio du navigateur et des
lecteurs tiers, on gagne quelque chose qui fonctionne encore dans six mois.

Trois points à connaître :

1. **Interroger une app à l'arrêt la lance.** D'où le test `isRunning` avant
   toute question — sans lui, LedgeNotch démarrerait Spotify tout seul.
2. **`NSAppleScript` n'est pas réentrant** et un événement Apple peut bloquer
   plusieurs dizaines de millisecondes. Tout passe par une file sérielle en
   arrière-plan, sinon l'animation de l'encoche hoquette.
3. **Le runtime durci bloque les événements Apple** sans l'autorisation
   `com.apple.security.automation.apple-events`. La construction en ad-hoc
   désactive ce runtime et masque le problème jusqu'au jour de la distribution,
   d'où le fichier `LedgeNotch.entitlements` dès maintenant.

Apple Music fournit les octets de la pochette directement ; Spotify ne donne
qu'une adresse, que l'app va chercher sur le réseau.

### YouTube

YouTube n'est pas une app mais un onglet, et se traite donc à part. Le pont
fonctionne à deux niveaux, volontairement séparés :

| Ce qu'on veut | Comment | Réglage nécessaire |
| --- | --- | --- |
| Titre | Titre de l'onglet | aucun |
| Vignette | Identifiant lu dans l'adresse, image servie par YouTube | aucun |
| État de lecture et commandes | JavaScript injecté dans la page | **oui** |

Les navigateurs refusent par défaut d'exécuter du JavaScript venu d'une autre
app. Le réglage existe — Affichage → Développeur dans Chrome, Développement
dans Safari — mais il est masqué et l'utilisateur doit l'activer lui-même.
D'où cette séparation : on affiche ce qu'on peut sans rien demander, et on
n'exige un réglage que pour ce qui l'impose vraiment.

Les onglets sont lus en deux requêtes plutôt qu'un par un : chaque accès à une
propriété est un événement Apple, et une fenêtre de cinquante onglets rendrait
le sondage interminable.

## Tableau de bord

La vue par défaut de l'encoche ouverte tient en trois colonnes : musique,
miroir, calendrier. Un tableau de bord plutôt qu'un onglet à choisir —
l'encoche s'ouvre une seconde, le temps d'un coup d'œil, et obliger à cliquer
avant de voir quoi que ce soit annulerait tout l'intérêt.

Une bande d'en-tête longe le boîtier caméra et porte les onglets à gauche,
l'engrenage à droite. Rien au centre : c'est là que se trouve le boîtier, et
tout ce qu'on y placerait serait invisible. Le contenu commence en dessous.

Les onglets se réduisent à leur icône, l'actif étant marqué par une pastille
pleine. Ce n'est pas un choix esthétique : la rangée doit tenir entre le bord
gauche et le boîtier, et des libellés complets faisaient passer les derniers
onglets dessous — invisibles sur la dalle, mais parfaitement présents sur une
capture d'écran, qui lit la mémoire vidéo.

**L'encoche ouverte s'ajuste à la page.** Chaque page déclare la largeur dont
elle a besoin : 720 points pour le tableau de bord, 540 pour la concentration.
Garder la largeur du tableau de bord pour un minuteur laisserait de larges pans
noirs de chaque côté.

Ces deux points sont liés : rétrécir l'encoche rapproche le boîtier du bord et
réduit d'autant la place des onglets. La rangée fixe donc une largeur minimale
d'environ 540 points, en dessous de laquelle les derniers onglets repasseraient
dans la zone aveugle.

Deux règles s'y appliquent :

- **La caméra ne démarre que sur un clic.** L'allumer à l'ouverture ferait
  clignoter la diode verte à chaque passage de souris en haut de l'écran, de
  quoi croire à une app qui espionne.
- **L'autorisation du calendrier n'est jamais demandée d'office.** Une alerte
  système qui surgit parce qu'on a effleuré l'encoche serait déplacée : c'est
  le bouton de la colonne qui la déclenche.

Attention au piège de la langue : `Locale.current` est bornée par les langues
que le paquet déclare prendre en charge. LedgeNotch n'en déclare aucune, et les
dates s'affichaient donc en anglais sur un système en français. D'où
`Locale.system`, qui lit `preferredLanguages` et échappe à cette limite.

## Météo

Les relevés viennent d'**Open-Meteo** : ni clé, ni inscription, ni compte.
WeatherKit d'Apple supposerait l'adhésion à l'Apple Developer Program, que ce
projet a justement choisi de ne pas payer pour l'instant.

La position vient de CoreLocation, sur demande explicite. Une ville saisie dans
les réglages la remplace, pour qui préfère ne pas activer la localisation.

La bande horaire couvre deux jours et défile au trackpad. Son bord droit
s'estompe : une bande coupée net ne dirait pas qu'il reste des heures au-delà.

Piège à connaître : `convertFromSnakeCase` trébuche sur les chiffres.
`temperature_2m` ne devient pas `temperature2m`, et le décodage échoue sans
autre signe qu'une colonne vide. Les clés sont donc déclarées à la main.

## Traduction

Tout se passe sur la machine : `Speech` transcrit le micro, `Translation`
traduit. Rien ne part sur un serveur, et l'ensemble fonctionne sans réseau une
fois les modèles de langue installés par le système.

Le micro ne s'ouvre que sur un clic, comme la caméra du miroir : une app qui
écoute dès qu'on effleure le haut de l'écran serait inacceptable.

Deux détails qui n'allaient pas de soi :

- **Une tâche de reconnaissance s'arrête d'elle-même au bout d'une minute.**
  Sans relance automatique, l'écoute cesserait en pleine phrase. Ce qui est
  déjà transcrit est conservé à part, sinon la relance effacerait tout.
- **La transcription change à chaque mot.** Traduire à chaque syllabe
  saturerait le moteur pour un résultat qu'on n'aurait pas le temps de lire :
  la traduction attend six dixièmes de seconde de silence.

`TranslationSession` n'existe qu'à partir de macOS 15, et une propriété stockée
ne se déclare pas sous condition de version : la colonne traduite vit donc dans
sa propre vue annotée, ce qui garde le reste compatible avec macOS 14.

## Concentration

Une séance minutée — quinze, vingt-cinq, cinquante ou quatre-vingt-dix minutes —
dont le décompte s'affiche sur l'encoche **repliée**. C'est là tout l'intérêt :
surveiller le temps qui reste sans ouvrir quoi que ce soit.

Le compartiment gauche de l'encoche repliée suit un ordre de priorité : une
séance en cours passe devant la pochette, car elle est bornée dans le temps et
c'est son décompte qu'on veut suivre. Rien ne disparaît pour autant — la
pochette se glisse derrière l'égaliseur à droite, et la pastille de Claude se
pose en écusson, puisqu'elle réclame une action.

Le temps restant se recalcule depuis une échéance plutôt que de se décrémenter :
un Mac mis en veille arrêterait un minuteur classique, et la séance reprendrait
au réveil comme si de rien n'était.

## Prompteur

Le texte se colle dans les réglages et défile dans l'encoche, la ligne en cours
détachée des autres. Deux façons d'avancer : au son de la voix, ou à vitesse
constante quand le micro n'est pas une option.

Le suivi vocal compare en continu ce qui est dit à ce qui est écrit. À chaque
bribe transcrite, on cherche les derniers mots entendus **devant** le curseur,
du plus long enchaînement au plus court : trois mots consécutifs ne se répètent
pratiquement jamais, là où un mot seul se retrouve partout. La recherche est
bornée à quarante-cinq mots d'avance, sans quoi un « le » ferait sauter à
l'autre bout du texte.

Les mots sont comparés sans accents, sans ponctuation et sans casse : la
reconnaissance vocale écrit « ça » là où le texte dit « Ca », et « c'est » là
où il dit « c'est, ».

Son onglet est le seul à droite du boîtier caméra. La rangée de gauche arrivait
à saturation, et cet espace-là était inutilisé.

## Feuille de route

- [x] Le socle : panneau, géométrie, survol, animation
- [x] Réglages : ouverture au survol, dépassement, retour haptique
- [x] Claude Code : état des sessions, pastille ambiante, alerte
- [x] Tableau de bord : musique, miroir, calendrier
- [x] Page météo : relevé courant et prochaines heures
- [x] Page traduction : transcription du micro et traduction locale
- [x] Page concentration : séances minutées, décompte sur l'encoche repliée
- [x] Prompteur : texte défilant, au rythme de la voix ou à vitesse fixe
- [ ] Étagère à fichiers (glisser-déposer)
- [x] Lecteur média — Apple Music, Spotify et YouTube, au choix
- [ ] Étendre le lecteur aux autres sources via
      [mediaremote-adapter](https://github.com/ungive/mediaremote-adapter)
- [ ] Réglages : écran cible, lancement au démarrage
- [ ] Icône et empaquetage `.dmg`

## Distribution

Le `.dmg` avec glisser-vers-Applications se fabrique gratuitement
(`brew install create-dmg`). En revanche, pour que l'app se lance sans l'alerte
« app endommagée » sur la machine de quelqu'un d'autre, il faut la signer avec
un Developer ID et la faire notariser — ce qui suppose l'adhésion à l'Apple
Developer Program (99 $/an). Décision reportée : ça ne bloque pas le développement.
