# HANDOFF — reprise marketing Radical QR

> **Lis ce fichier en premier quand tu reviens.** Il te dit où tu en es, quoi faire, et dans quel ordre.
> Dernière mise à jour : 2026-07-23. Tu changes de machine pour ~1 mois — tout est dans ce dossier `marketing/` (versionné avec le repo, donc te suit).

## 📁 Les documents

| Fichier | Contenu |
|---|---|
| [`00-growth-plan.md`](00-growth-plan.md) | La stratégie globale + les KPI. **Vue d'ensemble.** |
| [`01-aso-audit.md`](01-aso-audit.md) | Audit de la fiche App Store + textes optimisés prêts à coller |
| [`02-video-scripts.md`](02-video-scripts.md) | 10 storyboards vidéo faceless + setup de tournage |
| [`03-apple-search-ads.md`](03-apple-search-ads.md) | Structure de campagne Apple Search Ads + mots-clés |
| `HANDOFF.md` | Ce fichier — statut & checklist de reprise |

## ✅ État au 2026-07-23 (ce qui est fait)

- [x] Stratégie définie et documentée (contraintes : 1-2 h/sem, faceless, 100-150 €/mois)
- [x] Audit ASO réalisé, textes optimisés rédigés (pas encore appliqués)
- [x] 10 storyboards vidéo écrits (pas encore tournés)
- [x] Structure Apple Search Ads définie (compte pas encore créé)
- [ ] **RIEN n'est encore exécuté** — tout est prêt à lancer

## ❓ À confirmer avant de lancer

- **Prix du Pro** : supposé 4,99 € dans tous les calculs de CPI. Si différent → recalcule le seuil de rentabilité dans `03-apple-search-ads.md` (seuil ≈ prix × 10 %).
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
4. **Apple Search Ads** (1 h setup) — suis la checklist de `03-apple-search-ads.md` : compte Advanced, campagne France, 3 €/j, mots-clés Exact + négatifs.
5. Pose un **rappel hebdo vendredi** (20 min de pilotage).

### Quand tu as un samedi libre (pas dans le rythme hebdo)
6. **Tourner la banque de 10 vidéos** (`02-video-scripts.md`), monter, programmer.
7. **Préparer Product Hunt** (recycle un clip en GIF de démo).

## 📊 Tableau de suivi KPI (à remplir chaque vendredi)

Copie ce tableau et remplis-le chaque semaine. Source : App Store Connect + dashboard Apple Search Ads (aucun SDK).

| Semaine | Installs | CVR fiche | Achats Pro | Dépense ads | CPI | Notes |
|---|---|---|---|---|---|---|
| Baseline (juin) | 16 | ? | 2 | 0 € | — | avant marketing |
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
