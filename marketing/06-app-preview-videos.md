# (b-bis) App Preview — vidéos App Store

> Les **App Preview** (vidéos dans la fiche App Store), à ne pas confondre avec les vidéos **sociales** de `02-video-scripts.md`.
> **Pourquoi c'est prioritaire** : sur iOS, la 1re App Preview **se lance en autoplay (muet) directement dans les résultats de recherche** → elle attaque *pile* le goulot identifié dans les stats : le passage **impression → clic (1,9 %)**.

## ✅ État (nuit du 16 au 17 sept 2026)

**Les 8 vidéos sont produites** (2 storyboards × en-US, fr-FR, de-DE, es-ES), filmées sur l'app 2.1 réelle au simulateur et montées automatiquement.

- Fichiers : `appstore/previews/out/preview-1-paste-<locale>.mp4` et `preview-2-style-<locale>.mp4`
- Outillage pour les refaire à chaque version : `appstore/previews/` (voir son `README.md`), en une commande : `./appstore/previews/shoot.sh`
- **Rien n'est commité ni uploadé** : à valider par Nicolas.

## Règles Apple (vérifiées sur la doc officielle)

| Spec | Valeur |
|---|---|
| Emplacement | **iPhone 6.9″** (couvre aussi 6.7″ et 6.5″) |
| Résolution | **886 × 1920** portrait (et non la résolution native du device) |
| Format | .mov / .m4v / .mp4 en H.264 (ou ProRes 422 HQ), **30 fps max** |
| Durée | **15 à 30 s** |
| Audio | piste **stéréo AAC 256 kbps**, 44,1 ou 48 kHz, obligatoire (peut être silencieuse) |
| Poids | 500 Mo max |
| iPad 13″ (plus tard) | 1200 × 1600 |

Autres règles : **vraie capture de l'app** (les incrustations de texte sont admises), jusqu'à **3 vidéos par langue**, **muet par défaut** dans la recherche, **poster frame** choisie dans App Store Connect au moment de l'upload.

## 🎬 Storyboard 1 — « Paste it as written » (~20 s)

Le film de la nouveauté 2.1 : du texte collé tel quel devient le bon formulaire.

| Plan | À l'écran | Légende (en-US) |
|---|---|---|
| Intro | Écran d'accueil « Drop or paste anything » | *Paste it as written. / The form fills itself in.* |
| 1 | « Dinner Saturday 8pm, 350 Fifth Avenue, New York » → **formulaire événement** rempli + QR | *An appointment / becomes a calendar event* |
| 2 | « Wi-Fi: CafeGuest / Password: … » → **formulaire Wi-Fi** | *A Wi-Fi card / joins in one scan* |
| 3 | Signature d'e-mail → **fiche contact** (nom, poste, société, tél., e-mail, site) | *A signature / becomes a contact* |
| 4 | Une adresse seule → **lieu** qui s'ouvre dans Plans | *An address / opens in Maps* |
| Fin | Palette → dégradé violet sur le QR | *Private. On your device. / No tracking.* |

Exemples localisés (FR : « Dîner samedi 20h, 12 rue de Rivoli, Paris » ; DE : « Abendessen Samstag 20 Uhr, Hauptstraße 5, Berlin » ; ES : « Cena sábado 20h, Calle Gran Vía 28, Madrid »), **chacun vérifié dans l'app** pour ouvrir le bon formulaire en confiance haute.

## 🎬 Storyboard 2 — « Make it yours » (~24 s)

| Plan | À l'écran | Légende (en-US) |
|---|---|---|
| 1 | On colle un lien → QR | *Any link. / A QR code in a second.* |
| 2 | Couleurs : dégradé cyan puis violet | *Colors / and gradients* |
| 3 | Forme : modules ronds, yeux ronds | *Round the dots, / round the eyes* |
| 4 | Logo au centre + légende « radicalsolution.com » | *Your logo. / Dead centre.* |
| 5 | Export : SVG, 4096 px | *SVG, PDF, PNG / up to 4096 px* |

## Mise en forme

Même identité que les captures du Store : fond dégradé `#667eea → #764ba2`, iPhone à bordure sombre au centre, légende en SF Pro Display Bold blanc au-dessus (jamais sur l'UI), fondus courts entre légendes.

## Comment ça a été fait (et les pièges)

- **Pilotage par XCTest** d'une copie du projet (le dépôt n'est pas touché), enregistrement `simctl io recordVideo` pendant le test.
- Le **bouton Coller d'iOS (`PasteButton`) refuse les taps simulés** (contrôle sécurisé) : un petit crochet `#if DEBUG`, appliqué seulement à la copie, exécute exactement la même affectation que ce bouton. Idem pour le logo (le sélecteur Photos est remplacé).
- **Tests en parallèle désactivés** : sinon xcodebuild teste sur un *clone* du simulateur, et on filme l'original inactif (vidéos vides).
- Le montage repère le vrai début et la vraie fin de chaque animation (score de scène ffmpeg) et **compresse les blocages** dus à une machine chargée : le rythme final est celui de l'app, pas celui du test.

## Checklist

- [x] Feature 2.1 (texte collé → formulaires) filmée
- [x] Storyboard 1 × 4 langues
- [x] Storyboard 2 × 4 langues
- [x] Specs Apple : 886×1920, H.264 30 fps, AAC stéréo 48 kHz, 15-30 s
- [ ] Revue par Nicolas (et musique éventuelle dans FCPX)
- [ ] Commit de `appstore/previews/` (vidéos + outillage)
- [ ] Upload dans App Store Connect (iPhone 6.9″, 4 langues) + choix des poster frames
- [ ] Soumettre la 2.1 avec les vidéos (voir mémoire : la 2.1 attendait les vidéos)
