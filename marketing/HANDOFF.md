# HANDOFF — reprise marketing Radical QR

> **Lis ce fichier en premier quand tu reviens.** Il te dit où tu en es, quoi faire, et dans quel ordre.
> Dernière mise à jour : 2026-09-02. Tu changes de machine pour ~1 mois — tout est dans ce dossier `marketing/` (versionné avec le repo, donc te suit).

## 📉 Baseline chiffrée (point zéro AVANT marketing)

Source : App Store Connect, RadicalQR **seul** (isolé de Phone Number Cleaner), 90 jours 4 juin → 1 sept 2026.

| Métrique | Valeur | Note |
|---|---|---|
| Téléchargements | **40** sur 90 j (~13-15/mois) | +233 % vs trimestre précédent (12) — en accélération |
| Achats Pro | **4** | tous entre juillet et fin août, ~1 vente / 2-3 sem |
| **Conversion download → Pro** | **10 %** | excellent pour un utilitaire (marché : 1-5 %) |
| Prix Pro | **4,99 € / $4.99** ✅ confirmé | $21,63 brut ÷ 4 ≈ 5,40 $ ≈ 4,99 € |
| Revenu Pro brut | **21,63 $** sur 90 j (~7 $/mois) | net ≈ 18 $ (small business 85 %) |
| CVR fiche (page→install) | à mesurer | go/no-go des ads |

**Diagnostic : l'entonnoir convertit (10 %), il manque le débit en haut.** Économie unitaire : valeur d'un install ≈ 10 % × ~4,24 $ net ≈ **0,42 $** → seuil CPI ≈ 0,42 $, tolérable ~0,60-0,80 $. La math des docs (`03-apple-search-ads.md`) est calibrée juste — rien à réécrire.

> ⚠️ Ne pas confondre avec l'écran "Tendances 26 sem." qui **agrège les 2 apps** (RadicalQR + Phone Number Cleaner) : 66 unités / 65 $ y mélangent les deux. La baseline ci-dessus est RadicalQR pur.

## 📁 Les documents

| Fichier | Contenu |
|---|---|
| [`00-growth-plan.md`](00-growth-plan.md) | La stratégie globale + les KPI. **Vue d'ensemble.** |
| [`01-aso-audit.md`](01-aso-audit.md) | Audit de la fiche App Store + textes optimisés prêts à coller |
| [`02-video-scripts.md`](02-video-scripts.md) | 10 storyboards vidéo faceless + setup de tournage |
| [`03-apple-search-ads.md`](03-apple-search-ads.md) | Structure de campagne Apple Search Ads (référence stratégique) |
| [`04-campaign-setup-US.md`](04-campaign-setup-US.md) | **Runbook exécutable — USA, marché n°1** (50 €/mois) ← à lancer en premier |
| [`05-campaign-setup-FR.md`](05-campaign-setup-FR.md) | Runbook France — marché secondaire, à lancer plus tard |
| `HANDOFF.md` | Ce fichier — statut & checklist de reprise |

## ✅ État au 2026-09-02 (ce qui est fait)

- [x] Stratégie définie et documentée (contraintes : 1-2 h/sem, faceless, 100-150 €/mois)
- [x] Audit ASO réalisé, textes optimisés rédigés (pas encore appliqués)
- [x] 10 storyboards vidéo écrits (pas encore tournés)
- [x] Structure Apple Search Ads définie (`03`) + **runbook exécutable 50 €/mois prêt à copier-coller** (`04`, compte pas encore créé)
- [ ] **RIEN n'est encore exécuté** — tout est prêt à lancer

## ❓ À confirmer avant de lancer

- ~~**Prix du Pro**~~ ✅ **Confirmé 4,99 € / $4.99** (cf. baseline ci-dessus). La math CPI des docs tient.
- **Décision sur le keyword `scan`** : le garder en ASO (volume) ou le remplacer par `print` (irréprochable) — cf. `01-aso-audit.md`.

## 🎯 Ordre d'exécution recommandé (quand tu reviens)

### Semaine 1 — Fondations (le plus important)
1. **Optimiser la fiche App Store** (45 min) — applique les textes de `01-aso-audit.md` :
   - Édite `appstore/metadata/en-US/subtitle.txt` (Option B : `Custom QR Maker with Logo`)
   - Édite `appstore/metadata/en-US/keywords.txt` (version 99 car.)
   - Idem fr-FR à la main
   - `./updAppStore.sh --dry-run` puis `./updAppStore.sh`
   - ⚠️ subtitle/keywords ne s'appliquent qu'à la **prochaine build soumise**
2. **Créer les comptes sociaux** (20 min) — @radicalsolution sur TikTok + Instagram, réserver les autres handles.
3. **Vérifier la CVR fiche** dans App Store Connect (baseline actuelle) — c'est le go/no-go pour les ads.

### Semaine 2 — Lancer le moteur
4. **Apple Search Ads — USA d'abord** (1 h setup) — suis le runbook prêt à copier-coller `04-campaign-setup-US.md` : compte Advanced, 1 campagne **United States** à 1,70 €/j (50 €/mois), 3 groupes (Exact-Intent / Discovery / Brand), mots-clés + négatifs déjà rédigés. La France (`05`) attend que les USA soient rentables.
5. Pose un **rappel hebdo vendredi** (20 min de pilotage).

### Quand tu as un samedi libre (pas dans le rythme hebdo)
6. **Tourner la banque de 10 vidéos** (`02-video-scripts.md`), monter, programmer.
7. **Préparer Product Hunt** (recycle un clip en GIF de démo).

## 📊 Tableau de suivi KPI (à remplir chaque vendredi)

Copie ce tableau et remplis-le chaque semaine. Source : App Store Connect + dashboard Apple Search Ads (aucun SDK).

> Rappel baseline pré-marketing (RadicalQR seul, 90 j) : ~13-15 installs/mois · conversion 10 % · ~1-1,5 Pro/mois · 0 € ads. C'est le point zéro à battre.

| Semaine | Installs | CVR fiche | Achats Pro | Dépense ads | CPI | Notes |
|---|---|---|---|---|---|---|
| Baseline (90j→sept) | ~13-15/mois | ? | 4 (sur 90j) | 0 € | — | organique pur, avant marketing |
| S1 | | | | | | |
| S2 | | | | | | |
| S3 | | | | | | |
| S4 | | | | | | |

**Rappels de seuils :**
- CVR fiche cible ≥ 25 % (sinon retravaille l'ASO avant de dépenser)
- CPI cible < 1 € (idéal < 0,50 €). Si < 0,50 € → monte le budget. Si > 1,50 € → problème de fiche.
- North Star = achats Pro/mois. Cibles : 5 (M+1), 18 (M+3).

## 🔑 Outils / accès nécessaires

- **App Store Connect** : analytics + A/B screenshots (Product Page Optimization) + soumission métadonnées
- **Apple Search Ads Advanced** : searchads.apple.com (compte séparé, gratuit)
- **Pipeline métadonnées** : `./updAppStore.sh` (credentials déjà dans `../.env` : DEEPL_API_KEY, ASC_*)
- **CapCut** (gratuit) pour le montage vidéo
- **TikTok + Meta Business Suite** pour la programmation des posts

## 💡 Idée liée déjà notée

- Prompt de notation App Store toutes les X générations de QR (cf. mémoire projet `idea-appstore-rating-prompt`) → à implémenter : améliore la note = meilleure CVR = ads plus rentables. **Synergie directe avec ce plan.**

---

*Quand tu reviens et que tu as avancé : mets à jour la section « État » et le tableau KPI de ce fichier, puis relance une session avec Claude en pointant ce dossier.*
