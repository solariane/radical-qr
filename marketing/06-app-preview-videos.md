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
