# (c) Apple Search Ads — structure de campagne

> Ton moteur d'acquisition principal (compense le peu de temps dispo).
> Budget : **~100-150 €/mois** → commencer à **3 €/jour**, monter vers 5 €/j une fois le CPI validé.
> Outil : **Apple Search Ads Advanced** (gratuit, contrôle fin des mots-clés). PAS "Basic" (trop opaque).
> Prérequis bloquant : **ne lance rien tant que la CVR fiche < 25 %** (cf. `01-aso-audit.md`).

## La math de rentabilité (à garder en tête)

Hypothèse prix Pro = **4,99 €** (à confirmer). Conversion install→Pro observée ≈ **12,5 %** (échantillon minuscule, traite ~8-10 % comme prudent).

```
Valeur directe d'un install ≈ 4,99 € × 10 % ≈ 0,50 €  (hors LTV, bouche-à-oreille, familles Family Sharing)
```

➡️ **Seuil de rentabilité brut : CPI ≈ 0,50 €.**
➡️ **Cible de départ réaliste : CPI < 1 €** (on tolère de perdre un peu au début pour apprendre + le halo organique compense).
➡️ Si le CPI descend < 0,50 € → **monte le budget**, tu imprimes de l'argent.

> Note : Apple Search Ads reporte le **TTR** (tap-through rate) et le **conversion rate** (tap→install). Ces deux chiffres × ton CPT (coût par tap) déterminent le CPI. Un mauvais CPI vient soit d'une fiche faible (CVR basse → re-travaille l'ASO) soit d'enchères trop hautes sur des termes concurrentiels.

## Structure des campagnes

Apple Search Ads = 1 campagne par **marché (pays)** et par **type de correspondance**. On garde ça minimal.

### Marchés à cibler (par ordre de priorité)

| # | Marché | Storefront | Pourquoi |
|---|---|---|---|
| 1 | 🇫🇷 France | fr-FR | Ton marché, métadonnées hand-written, CPT bas |
| 2 | 🇺🇸 USA | en-US | Plus gros volume, mais CPT plus cher — budget limité |
| 3 | 🇩🇪🇪🇸🇮🇹 (à ouvrir en M2) | de/es/it | CPT modéré, app déjà localisée |

➡️ **Démarrage : France seule** (ou France + un petit test US). Concentre les 3 €/j pour avoir des données statistiquement lisibles vite. Ouvre les autres marchés quand la France est rentable.

### Les 3 groupes de pub (ad groups) par campagne

| Ad group | Match type | Budget indicatif | Rôle |
|---|---|---|---|
| **Discovery** | Search Match ON + Broad | ~1 €/j | Machine à découvrir des mots-clés pas chers qu'on n'aurait pas devinés |
| **Brand** | Exact | ~0,50 €/j | Défensif : capter "radical qr" pour pas qu'un concurrent te vole tes propres recherches (CPT quasi nul) |
| **Generic-Exact** | Exact | ~1,50 €/j | Le cœur : mots-clés à intention forte, enchères contrôlées |

## Mots-clés Exact (ad group Generic-Exact)

### 🇫🇷 France
```
qr code
générateur qr
créer qr code
qr code logo
qr code personnalisé
générateur de qr code
code qr
qr wifi
```

### 🇺🇸 USA
```
qr code
qr code generator
qr code maker
custom qr code
qr code with logo
qr generator
create qr code
wifi qr code
```

> Enchère de départ (CPT max) : commence à **~0,40-0,60 €** par mot-clé, ajuste selon ce que Search Ads recommande. Baisse les termes ultra-concurrentiels ("qr code" seul est cher) si le CPI dérape ; garde les longue-traîne ("qr code with logo") qui convertissent mieux et coûtent moins.

## Mots-clés négatifs (à mettre dès le départ)

Empêche de brûler du budget sur des recherches non pertinentes. À ajouter au niveau **campagne** :

```
scanner          (tu ne scannes pas — évite les déçus)
scan
reader
lecteur
lecteur qr
free (si tu vois qu'il attire des non-acheteurs — à surveiller, pas à bloquer d'emblée)
business card scanner
inventory
```

> ⚠️ Contradiction assumée avec l'ASO : en **keyword ASO** on tolérait "scan" pour le volume, mais en **paid** on le met en **négatif** — parce qu'ici tu paies chaque clic et un utilisateur qui cherche à *scanner* ne convertira pas en Pro. Deux logiques différentes.

## Boucle d'optimisation hebdomadaire (~20 min/semaine)

Chaque vendredi, dans le dashboard Apple Search Ads :

1. **Search Terms report** (onglet Discovery) → repère les termes qui ont converti à bas coût → **passe-les en Exact** dans Generic-Exact.
2. **Termes qui dépensent sans convertir** → ajoute-les en **négatif**.
3. **Regarde le CPI par mot-clé** :
   - CPI < 0,50 € → **monte l'enchère** de ce mot-clé (+20 %) pour prendre plus de volume.
   - CPI > 1,50 € → **baisse l'enchère** (-20 %) ou mets en pause.
4. **Vérifie le budget total consommé** : si tu ne dépenses pas tes 3 €/j → tes enchères sont trop basses (tu perds les enchères) → monte-les. Si tu exploses → baisse.
5. **Note les chiffres** dans le tableau de suivi (voir HANDOFF.md).

## Paliers de décision (règles simples)

| Situation après 2 semaines | Action |
|---|---|
| CPI < 0,60 € et budget consommé | 🚀 Monte le budget à 5 €/j, ouvre le marché US |
| CPI 0,60-1,20 € | ✅ Continue, optimise les mots-clés, patiente |
| CPI > 1,50 € malgré optimisation | 🔧 Problème de fiche → retour à l'ASO avant de dépenser plus |
| Budget non consommé | ⬆️ Enchères trop basses → augmente les CPT max |

## Checklist de lancement

- [ ] CVR fiche vérifiée ≥ 25 % (sinon → ASO d'abord)
- [ ] Compte Apple Search Ads Advanced créé (searchads.apple.com)
- [ ] Prix Pro confirmé (pour recalculer le seuil de CPI)
- [ ] Campagne France créée, 3 ad groups, budget 3 €/j
- [ ] Mots-clés Exact FR ajoutés (enchères 0,40-0,60 €)
- [ ] Mots-clés négatifs ajoutés (scanner, reader…)
- [ ] Rappel hebdo vendredi posé (revue 20 min)
- [ ] Après 2 semaines : appliquer les paliers de décision
