# Mémo — captures App Store 2.0

Réécrit le 01/09/2026, après la session qui a refait le générateur de captures.
Le mémo précédent décrivait un chantier à faire ; celui-ci décrit ce qui existe.

## Où on en est

- Les 17 scènes sont redessinées sur l'UI réelle de la 2.0 (rail d'icônes,
  tuiles `SettingTile`, glyphes, `LaunchCard`, ligne d'actions épinglée).
- La scène **Duplication** — l'argument n°1 de la 2.0 — existe enfin, sur
  iPhone et sur iPad.
- La signature RadicalSolution.com • *Privacy First, Privacy by Design* est en
  pied de **toutes** les captures.
- Les textes marketing sont sortis des scènes : ils vivent dans
  `copy/<locale>.json`, traduits par DeepL comme le reste de la fiche.
- L'envoi vers App Store Connect est automatisé (`./updScreenshots.sh`).

## Comment ça marche

Ce ne sont toujours pas des captures de simulateur : chaque scène écrit un SVG
où l'écran de l'app est redessiné, puis rasterisé.

    copy/<locale>.json ─┐
                        ├─> scenes/*.mjs ─(node)─> out/*.svg ─(rsvg)─> out/*.png
    lib/app-ui.mjs ─────┘

La différence avec l'ancienne version tient dans `lib/` :

| Fichier | Rôle |
|---|---|
| `app-ui.mjs` | **Chaque composant SwiftUI redessiné**, aux valeurs des quatre préréglages de `GeneratorMetrics`, plus `fittingMetrics()` qui recopie `fitting(width:height:)`. C'est le fichier qui garde les captures honnêtes. |
| `screens.mjs` | Écrans complets (générateur, écran de lancement), partagés par les trois plateformes. |
| `symbols.mjs` | Les SF Symbols de l'app, redessinés (rsvg n'a pas la police). |
| `copy.mjs` | Charge `copy/<locale>.json`, avec repli sur en-US. |
| `signature.mjs` | Le pied de page RadicalSolution.com. |
| `poster.mjs` | Le décor autour de l'appareil : badges, listes à puces, écriture du SVG. |
| `phone-frame` / `ipad-frame` / `mac-frame` | Les châssis, et l'échelle points → pixels. |

**Le point important** : les écrans sont dessinés en **points SwiftUI** puis mis
à l'échelle. Un nombre de `GeneratorMetrics` se recopie donc tel quel dans
`app-ui.mjs`, au lieu d'être re-réglé à l'œil. Si la mise en page de l'app
change, ce sont les préréglages et `fittingMetrics()` en haut de `app-ui.mjs`
qu'il faut mettre à jour — pas chaque scène.

## Ce qui a été corrigé au passage

- **L'iPad n'a jamais eu de sidebar.** `ContentView` ne fait un
  `NavigationSplitView` que sous `#if os(macOS)` ; l'iPad reçoit le même
  `NavigationStack` que l'iPhone. Les anciennes scènes iPad dessinaient une
  colonne latérale inventée. `ipad-frame.mjs` a été refait.
- **L'app n'adaptait pas sa mise en page à l'iPad**, ce que les premières
  captures fidèles ont rendu visible : aperçu de 186pt dans une carte de 992pt.
  Corrigé dans l'app (préréglages `expanded` et `split`), et les captures
  suivent — voir la section ci-dessous.
- Les scènes qui affichaient encore « Sharp / Slight / Rounded / Circular » en
  capsules de texte — ce que la 2.0 a précisément supprimé — sont mortes.
- Le nom du PNG 6.5" était `…-6.9-<locale>-6.5.png`, ce qui plaçait la locale au
  milieu et le rendait invisible pour tout script d'envoi. Il s'appelle
  maintenant `…-iphone-6.5-<locale>.png`.

## Les scènes

| iPhone (7) | iPad (5) | Mac (5) |
|---|---|---|
| `01-hero` | `p01-hero` | `m01-hero` |
| `02-launch` — écran de lancement | `p02-brand` — logo + légende | `m02-services` — clic droit |
| `03-duplicate` — **nouveau** | `p03-customization` | `m03-customization` |
| `04-customization` | `p04-duplicate` — **nouveau** | `m04-history` |
| `05-brand` — logo + légende | `p05-privacy` | `m05-privacy` |
| `06-export` | | |
| `07-privacy` | | |

App Store Connect n'affiche que 10 captures par appareil : il reste de la marge.

## Les textes

`copy/en-US.json` est la source de vérité. `copy/fr-FR.json` est écrit à la
main (comme `appstore/metadata/fr-FR`) et n'est jamais écrasé — `config.json`
le marque `isHandWritten`. Les huit autres langues sont produites par :

    cd appstore/screenshots && node translate-copy.mjs

Le script reprend les règles du reste du pipeline : protection des marques
(`deepl-protect.mjs`), `context` DeepL par clé (c'est ce qui évite qu'« Eyes »
devienne un organe), et invalidation par hachage — seule une chaîne anglaise
*modifiée* est retraduite, donc une correction faite à la main sur une autre
langue survit.

Ne sont jamais traduits (liste `NEVER_TRANSLATE`) : la signature de marque, les
acronymes de format, les tailles en pixels, les URL de démonstration.

Les chaînes qui existent aussi dans l'app sont **recopiées telles quelles** de
`Localizable.xcstrings` dans `fr-FR.json`. Une capture qui dit « Enregistrer le
QR » à côté d'une app qui dit « Enregistrer le code QR » se lit comme une autre
app.

## Rendu

    brew install librsvg          # une fois
    ./appstore/screenshots/render.sh              # toutes les langues qui ont un copy/
    ./appstore/screenshots/render.sh fr-FR        # une seule
    ./appstore/screenshots/render.sh --clean      # vide out/ d'abord

Les titres et sous-titres se **redimensionnent seuls** (`fitFontSize`) : une
accroche allemande ne déborde plus du cadre, une japonaise ne reste plus
minuscule. La mesure est une estimation par table de chasses, pas un moteur de
texte — vérifier une langue nouvelle à l'œil reste utile.

## Envoi vers App Store Connect

    ./updScreenshots.sh                  # traduire + rendre + envoyer
    ./updScreenshots.sh --render-only    # ni DeepL ni ASC
    ./updScreenshots.sh --upload-only
    ./updScreenshots.sh --dry-run
    ./updScreenshots.sh --only=fr-FR

`appstore-screenshots.mjs` est repris de `cleanUpPhoneNumbers` : réservation de
l'asset, PUT découpés, PATCH avec somme MD5, puis attente de
`assetDeliveryState`. Par défaut il **remplace** le jeu de captures d'un type
d'affichage ; `--keep` ajoute à côté.

Identifiants attendus dans `../.env`, comme `updAppStore.sh` :
`DEEPL_API_KEY`, `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_KEY_PATH`.

## Dimensions

Définies dans `render.sh`, qui reste la source de vérité :

| Cible | Pixels | Nom de fichier |
|---|---|---|
| iPhone 6.9" | 1290 × 2796 | `<scène>-iphone-6.9-<locale>.png` |
| iPhone 6.5" | 1284 × 2778 | `<scène>-iphone-6.5-<locale>.png` |
| iPad 13" | 2064 × 2752 | `<scène>-ipad-<locale>.png` |
| Mac | 2880 × 1800 | `<scène>-mac-<locale>.png` |

Apple fait évoluer ses exigences : revérifier dans App Store Connect avant de
tout rendre.

## Les quatre mises en page

`GeneratorMetrics.fitting(width:height:)` choisit entre quatre jeux de valeurs,
et `GeneratorView` entre deux arrangements. `app-ui.mjs` recopie les quatre, et
`screens.mjs` dessine les deux — parce que ce sont deux écrans réels :

| Canevas | Préréglage | Arrangement | Où |
|---|---|---|---|
| < 700 de haut | `compact` | colonne | iPhone SE, 8 |
| < 700 de large | `regular` | colonne | iPhone |
| ≥ 700 des deux côtés, plus haut que large | `expanded` | colonne, plafonnée à 640 | iPad debout |
| ≥ 700 des deux côtés, plus large que haut | `split` | deux colonnes | fenêtre Mac, iPad couché |

Chaque scène appelle `fittingMetrics(largeur, hauteur)` avec le canevas qu'elle
dessine, et reçoit le préréglage que l'app choisirait. Un iPad 13" debout tombe
donc sur `expanded` avec un aperçu de 480pt ; le volet de détail du Mac
(972 × 780) tombe sur `split`, réglages à côté du code.

**C'est la fonction à garder identique.** Si `fitting` change dans le Swift,
c'est elle qu'il faut recopier — pas les scènes.

## Ce qui reste

1. **Traduire les huit autres langues** : il faut une clé DeepL, absente de la
   machine où ceci a été écrit. `copy/` ne contient donc que en-US et fr-FR ;
   les autres locales tombent en anglais tant que le script n'a pas tourné.
2. **Envoyer** : les identifiants ASC manquaient aussi. `--dry-run` d'abord.
3. `LaunchCard` garde ses tailles fixes (18 de marge, cible de 164, capsules de
   36) : sur iPad c'est une petite carte dans une colonne de 640, avec les deux
   tiers de l'écran en dessous. C'est pour ça que la scène de lancement iPad a
   été remplacée par `p02-brand` — `p05-privacy` montre déjà cet écran, et le
   vide y sert l'argument. Si `LaunchCard` prend un jour des tailles issues de
   `GeneratorMetrics`, il y aura une capiture iPad de plus à récupérer.
