# Mémo — refaire les captures App Store pour la 2.0

Écrit le 31/08/2026, à la fin de la session qui a livré la 2.0 et poussé les
textes marketing. À lire en premier pour reprendre le chantier captures, y
compris sur une autre machine.

## Où on en est

- L'app 2.0.0 est en `PREPARE_FOR_SUBMISSION` sur les deux plateformes.
- Textes, mots-clés, notes de version : traduits, poussés, validés (commit `3945844`).
- **Captures : rien de fait pour la 2.0.** Celles en ligne montrent l'UI d'avant.

## Comment marche le générateur de captures

Ce ne sont **pas** des captures de simulateur. Chaque scène est un script Node
autonome qui écrit un SVG où l'écran de l'app est **redessiné à la main**, puis
rasterisé.

    scenes/*.mjs  --(node)-->  out/*.svg  --(rsvg-convert)-->  out/*.png

- `./render.sh [locale]` (défaut `en-US`) exécute toutes les scènes puis convertit.
- `lib/phone-frame.mjs`, `ipad-frame.mjs`, `mac-frame.mjs` dessinent les châssis.
- `lib/qr-svg.mjs` dessine un vrai QR (`renderQR`).
- Les textes marketing sont **codés en dur dans chaque scène**, objet `COPY`,
  et seuls `en-US` et `fr-FR` existent. Ce ne sont pas les `.xcstrings` de l'app.

Conséquence : mettre les captures à jour = **réécrire du SVG**, pas relancer un
simulateur. Aucun build de l'app n'est nécessaire.

## Prérequis sur une nouvelle machine

    brew install librsvg      # fournit rsvg-convert

Node suffit pour le reste (aucune dépendance npm dans les scènes). Vérifié ici
avec rsvg-convert 2.62.3. `out/` est **suivi par git** (43 fichiers), donc les
PNG déjà rendus arrivent avec le dépôt.

## Ce qu'il faut changer pour la 2.0

Cinq scènes dessinent encore les libellés texte des options — « Modules »,
« Eyes », « Rounded », « Sharp », « Circular ». C'est précisément ce que la 2.0
a supprimé, et ce que les notes de version mettent en avant. Ces captures
contredisent donc l'argumentaire :

    03-customization-iphone.mjs
    p03-customization-ipad.mjs
    m03-customization-mac.mjs
    01b-eye-styles-iphone.mjs
    m01b-eye-styles-mac.mjs

À redessiner vers l'UI réelle de la 2.0 :

- **Rail d'icônes** à 5 familles (`CustomizationRail.swift` : styles, color,
  shape, brand, export), une seule famille visible à la fois.
- **Tuiles** carrées à coins adoucis avec anneau de sélection concentrique
  (`SettingTile.swift`), et cadenas d'angle pour le Pro.
- **Glyphes** : chaque option dessine son propre résultat (`ShapeGlyphs.swift`).
  Géométrie à respecter pour que la capture montre ce que l'app exporte :
  œil de 7 unités, anneau de 1, pupille de 3, remplissage even-odd.
- **Écran de lancement** (`LaunchCard.swift`) : cible de dépôt en pointillés,
  marque, champ intégré, trois capsules — Coller / Dupliquer / Parcourir les
  fichiers.

Scène **manquante** : la duplication d'un QR (photo ou caméra) est l'argument
n°1 de la 2.0, présent dans le promo et les notes de version, et aucune capture
ne le montre. À créer — c'est probablement la plus rentable des captures.

Sources visuelles : `design/mockup/*.dc.html` dans le dépôt, et l'artifact
https://claude.ai/code/artifact/23ffd34d-6af1-48b7-bc2f-80bbbefd7def

## Dimensions

Définies dans `render.sh`, qui reste la source de vérité :

| Cible | Pixels | Suffixe des fichiers |
|---|---|---|
| iPhone 6.9" | 1290 × 2796 | `-iphone-6.9-<locale>.png` |
| iPhone 6.5" | 1284 × 2778 | `…-6.5.png` (même dessin) |
| iPad 13" | 2064 × 2752 | `-ipad-<locale>.png` |
| Mac | 2880 × 1800 | `-mac-<locale>.png` |

Apple fait évoluer ses exigences : revérifier dans App Store Connect avant de
tout rendre.

## Envoi vers App Store Connect

**`appstore-push.mjs` ne gère pas les captures** (zéro occurrence de
« screenshot »). `./updAppStore.sh` ne les enverra donc jamais : le dépôt des
images se fait **à la main** dans App Store Connect, ou il reste à écrire.

## Décisions à prendre demain

1. **Combien de langues ?** Les scènes ne portent que `en-US` et `fr-FR`, alors
   que la fiche existe en 10 langues. Ajouter des locales = ajouter des entrées
   `COPY` dans chaque scène. Une capture en anglais sur une fiche japonaise est
   acceptée par Apple, mais convertit moins bien.
2. **Automatiser l'envoi** ou déposer à la main cette fois-ci.
3. **Quelles scènes garder** : les 16 actuelles, ou resserrer sur les 5 à 6 qui
   portent vraiment l'argumentaire 2.0.
