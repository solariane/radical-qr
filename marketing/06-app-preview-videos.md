# (b-bis) App Preview — storyboards vidéo App Store

> Les **App Preview** (vidéos dans la fiche App Store) — à ne pas confondre avec les vidéos **sociales** de `02-video-scripts.md`. Elles peuvent réutiliser des plans communs, mais obéissent aux règles d'Apple.
> **Pourquoi c'est prioritaire** : sur iOS, la 1re App Preview **se lance en autoplay (muet) directement dans les résultats de recherche** → elle attaque *pile* le goulot identifié dans les stats : le passage **impression → clic (1,9 %)**. C'est le levier ASO le plus aligné avec notre donnée.

## Règles Apple à respecter (≠ screenshots dessinés)

- **Vraie capture de l'app obligatoire.** Apple refuse le pur motion-design / marketing. Il faut filmer l'UI réelle.
- **15-30 secondes**, **portrait**, format .mov/.mp4 (H.264), jusqu'à **3 par langue**.
- **Muet par défaut** dans la recherche → tout doit se comprendre **sans son** (texte à l'écran, mouvement immédiat).
- **Poster frame** (image figée / vignette quand ça ne joue pas) : à choisir soigneusement, c'est elle qui vend quand l'autoplay ne se déclenche pas.
- **Zone de texte** : garde les incrustations dans le **tiers supérieur** — le bas de la vidéo est masqué par les boutons App Store.
- Commence par **en-US** (marché n°1), puis fr-FR en option. Le texte à l'écran est à localiser ; l'UI de l'app l'est déjà.

## Principe des 3 premières secondes

C'est ce qui s'affiche en autoplay dans la liste de résultats. **Pas d'intro, pas de logo au début** : on montre le résultat ou le « moment magique » immédiatement, en mouvement, avec un texte court et gros.

---

## 🎬 Storyboard 1 — « It reads what you type » (héros, ~25 s)

Le film de l'auto-détection, avec la **nouvelle détection d'événement** en vedette.

| Temps | À l'écran | Texte incrusté (haut) |
|---|---|---|
| **0-2 s** | Champ vide → on colle une **URL** → le QR apparaît **instantanément** | *"Paste anything."* |
| 2-5 s | On colle un **réseau Wi-Fi** → l'app affiche « Wi-Fi » détecté → QR | *"It knows what it is."* |
| 5-9 s | On colle une **vCard** (contact) → détecté → QR | *"Links, contacts, Wi-Fi…"* |
| **9-15 s** ⭐ | On tape **`21h mercredi 16/09`** → l'app propose/ouvre l'**éditeur d'événement**, titre focus → QR d'événement | *"Even plain text becomes an event."* |
| 15-20 s | On stylise : **gradient violet**, yeux arrondis, on dépose un **logo** au centre | *"Make it yours."* |
| 20-25 s | QR final qui « respire » + coche du **contrôle de scannabilité** ✓ | *"Private. No tracking."* |

- **Poster frame** : le QR final stylisé avec logo (la plus belle image).
- **Le pic d'intérêt** = le passage 9-15 s (texte → événement). Si tu ne devais garder qu'un moment, c'est celui-là — il est unique à ton app.

---

## 🎬 Storyboard 2 — « Beautiful, and it still scans » (option, ~20 s)

Le film « satisfying » de la personnalisation + l'argument print/Pro.

| Temps | À l'écran | Texte incrusté (haut) |
|---|---|---|
| **0-2 s** | Un QR noir basique | *"Your QR, but beautiful."* |
| 2-6 s | On fait défiler les **styles d'yeux** + on pousse le **slider d'arrondi** des modules | *"Round the dots. Round the eyes."* |
| 6-11 s | On applique un **gradient** (violet→bleu), on change le fond | *"Colors & gradients."* |
| 11-15 s | On dépose un **logo** → zone de silence automatique | *"Add your logo."* |
| 15-20 s | **Scannabilité ✓** puis flash des exports **PNG / SVG / PDF** | *"Exports that never blur. SVG, PDF."* |

- **Poster frame** : le QR gradient avec logo.

---

## Production (concret)

- **Capture** : sur un **vrai iPhone** (pas le simulateur — Apple peut refuser). Le plus simple sur Mac : connecter l'iPhone → **QuickTime → Nouvel enregistrement vidéo** → choisir l'iPhone comme source → enregistrer l'écran.
- **Device de référence** : filme sur un **iPhone 6.9″** (ex. 16 Pro Max) en portrait ; App Store redimensionne pour les tailles inférieures. (Résolutions exactes acceptées par ASC : à confirmer au moment de l'upload — Apple change la liste ; viser la résolution native du device.)
- **Montage** : CapCut ou iMovie. Ajoute le texte incrusté (gros, haut), coupe les temps morts, garde **< 30 s**.
- **Son** : mets une musique douce (elle jouera sur la fiche quand on tape la vidéo), mais **ne fais reposer aucune info sur le son** (autoplay muet dans la recherche).
- **Fond de marque** : le gradient `#667eea → #764ba2` est déjà à l'écran dans l'app → cohérence automatique.

## Recette technique (capture + montage)

### Emplacements & résolutions (une App Preview par famille de device)
App Store Connect a un emplacement séparé pour iPhone / iPad / Mac (ratios différents). **Priorité : iPhone seul pour commencer** (c'est là que joue l'autoplay dans la recherche + le gros du volume). iPad/Mac plus tard.

| Device | Résolution à viser (portrait) | Note |
|---|---|---|
| iPhone 6.9″ (16 Pro Max) | **1320 × 2868** | couvre tous les iPhones plus petits |
| iPad Pro 13″ | 2064 × 2752 | optionnel |
| Mac | 16:10 paysage (ex. 2880 × 1800) | UI différente (layout split) → tournage à part |

> Apple change parfois la liste des résolutions acceptées → vérifier dans ASC au moment de l'upload.

### Capture iPhone / iPad — au simulateur (pratique et propre)
```bash
# 1. Booter le device cible
xcrun simctl boot "iPhone 16 Pro Max"

# 2. Nettoyer la barre d'état (heure 9:41, batterie/onde pleines)
xcrun simctl status_bar booted override \
  --time "9:41" --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3

# 3. Lancer l'app puis enregistrer (Ctrl+C pour arrêter)
xcrun simctl io booted recordVideo --codec h264 beat.mov
```
- Alternative GUI : **Simulator → File → Record Screen**.
- **Repli device réel** (si review tatillonne) : **QuickTime → Nouvel enregistrement vidéo → source = iPhone**.

### Capture Mac
- **QuickTime → Nouvel enregistrement de l'écran** (ou Cmd+Shift+5), cibler la fenêtre de l'app.

### Montage FCPX
- Projet à la **résolution native de la capture**, **30 fps**.
- Trim des temps morts ; **texte incrusté dans le tiers supérieur** ; musique douce (jouée seulement sur la fiche, pas en autoplay recherche).
- Durée finale **15-30 s** ; export **H.264 .mov/.mp4**.
- **Poster frame** : ne se règle PAS dans FCPX → se choisit dans App Store Connect à l'upload.

### Division du travail possible (capture assistée)
Les captures iPhone/iPad peuvent être **produites automatiquement** (build + lancement simulateur + pilotage de l'UI + `recordVideo`), livrant des **clips bruts par beat** ; le montage créatif (texte, rythme, musique) reste dans FCPX. Bloqueur : le beat héros « texte → événement » attend que la feature de détection soit codée. Le Mac se capture mieux à la main (permissions d'enregistrement d'écran).

## Le timing malin — groupe tout dans une sortie de version

Tu codes la détection améliorée → sors **ensemble** : la **feature** + cette **App Preview** qui la met en scène + la **publication de version**. Triple effet :
1. une vraie nouveauté à montrer,
2. une vidéo qui booste le tap-through (le goulot des stats),
3. le coup de projecteur organique de la sortie de version (celui qui a fait le **+373 % d'impressions** avec la V2 du 2 sept).

## Réutilisation croisée

Les plans tournés ici (détection événement, gradient+logo, scannabilité) alimentent aussi les **vidéos sociales** de `02-video-scripts.md` — un seul tournage, deux usages. Différence : l'App Preview doit rester **100 % capture d'app** ; les vidéos sociales tolèrent plus de liberté (texte, memes, formats).

## Checklist

- [ ] Feature « détection événement » finalisée et stable à filmer
- [ ] Storyboard 1 tourné sur iPhone 6.9″ (QuickTime)
- [ ] (option) Storyboard 2 tourné
- [ ] Montage < 30 s, texte incrusté en haut, muet-compatible
- [ ] Poster frame choisie (QR final avec logo)
- [ ] Upload en-US dans App Store Connect (puis fr-FR en option)
- [ ] Publié dans la même version que la nouvelle détection
