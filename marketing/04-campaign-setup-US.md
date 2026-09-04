# (c-bis) Runbook Apple Search Ads — USA (marché principal, budget 50 €/mois)

> Version **exécutable** de `03-apple-search-ads.md` pour le **marché n°1 : les USA**.
> Le doc `03` reste la référence stratégique ; **pour le budget 50 € sur les USA, ce sont les chiffres ci-dessous qui font foi.**
> La France est traitée en secondaire dans `05-campaign-setup-FR.md` (à lancer plus tard).
> Outil : **Apple Search Ads Advanced** (searchads.apple.com) — gratuit. PAS "Basic".
> App : Radical QR : Générateur QR — Apple ID `6763236391`.

## ⚠️ Spécificité USA : marché cher → stratégie longue-traîne

Les USA sont le storefront le plus concurrentiel au monde. Le CPT (coût par clic) y est **2-4× celui de la France**. Conséquences directes sur un budget de 50 €/mois :

- CPI attendu : **0,60–1,50 €** (vs 0,35–0,80 € en France).
- Volume attendu : **~40-70 installs/mois** (vs ~100 en France pour le même budget).
- **Donc on NE mise PAS large.** On concentre le budget sur les mots-clés **longue-traîne à forte intention** (`qr code with logo`, `custom qr code`) et on **bride** ou surveille de près le terme générique cher `qr code`.

> Le seuil de rentabilité reste ~0,42 € (10 % × 4,24 € net). Sur les USA il sera plus dur à tenir au départ — c'est normal. Tu achètes surtout du **rang** et de l'**apprentissage** sur ton marché principal. Vise CPI < 0,80 €, tolérable jusqu'à ~1,20 € le temps d'optimiser.

## 💶 Devise & budget

- **Ton compte ASA a UNE seule devise** (choisie à la création — probablement EUR pour un dev français). **Tous les budgets et enchères sont dans cette devise**, même pour une campagne US. Les fourchettes suggérées par Apple s'afficheront dans ta devise.
- Budget quotidien : **1,70 €/jour** (≈ 50 €/mois). Les enchères ci-dessous sont exprimées dans la devise du compte (EUR supposé).

## ⚠️ Avant de lancer (go / no-go)

1. [ ] **ASO appliqué** — surtout le **sous-titre + keywords en-US** de `01-aso-audit.md` (c'est ton marché : soigne l'anglais).
2. [ ] **CVR fiche en-US vérifiée** dans App Store Connect. Idéal ≥ 25 %.
3. [ ] Compte Apple Search Ads **Advanced** créé + moyen de paiement.
4. [ ] Rappel hebdo vendredi posé.

## 🏗️ Structure à créer

**1 campagne**, 3 groupes de pub. Budget partagé au niveau campagne → on pilote par les enchères.

```
Campagne : "RadicalQR – US – Search"
├── Groupe 1 : "Exact – Intent"     (Search Match OFF, longue-traîne forte intention)  ← priorité
├── Groupe 2 : "Discovery"          (Search Match ON, découverte)                       ← exploration
└── Groupe 3 : "Brand"              (Search Match OFF, marque, défensif)                ← quasi gratuit
```

### Réglages campagne (à recopier)

| Champ | Valeur |
|---|---|
| Nom | `RadicalQR – US – Search` |
| App | Radical QR : Générateur QR |
| Pays / région | **United States** uniquement |
| Type | Search results |
| Budget quotidien | **1,70 €** (≈ 50 €/mois, devise du compte) |
| Plafond quotidien | laisser vide |
| Dates | Début aujourd'hui, pas de fin |

---

## 🎯 Groupe 1 — "Exact – Intent" (le cœur, ~75 % visé)

- **Search Match : OFF** · **Type : Exact** pour tous
- **Enchère max par défaut : 0,75 €** (ajuste à la fourchette suggérée par Apple)
- Audience : tout par défaut

**Mots-clés à coller (tout en Exact) :**

```
qr code with logo
custom qr code
qr code generator
qr code maker
qr code creator
create qr code
make a qr code
qr generator
wifi qr code
qr code for business
vcard qr code
qr code
```

**Enchères de départ suggérées** (affine par mot-clé après l'ajout global) :

| Mot-clé | Enchère max | Pourquoi |
|---|---|---|
| `qr code with logo` | **0,90 €** | Intention Pro maximale (feature payante n°1) |
| `custom qr code` | 0,85 € | Perso → Pro |
| `qr code generator` / `qr code maker` / `qr code creator` | 0,80 € | Cœur d'intention "créer" |
| `create qr code` / `make a qr code` / `qr generator` | 0,75 € | Idem, variantes |
| `qr code for business` | 0,70 € | Audience pro, bonne valeur |
| `wifi qr code` / `vcard qr code` | 0,55 € | Longue-traîne pas chère |
| `qr code` | **0,55 € (bridé)** | Générique CHER, beaucoup de chercheurs de "scanner". Enchère basse + surveille le CPI ; mets en pause s'il dérape |

> 💡 **Budget vraiment serré ?** Sur les USA, tu peux démarrer avec **seulement les 5 premiers mots-clés** (`with logo`, `custom`, `generator`, `maker`, `creator`) pour maximiser la conversion par euro, puis élargir quand tu as des données.

---

## 🔍 Groupe 2 — "Discovery" (exploration, ~15 %)

- **Search Match : ON** · pas de mots-clés à ajouter
- **Enchère max par défaut : 0,50 €** (sous l'Exact → le cœur garde la priorité)
- Rôle : trouver des requêtes US pas chères → récolte hebdo → passe les bonnes en Exact dans le Groupe 1.

---

## 🛡️ Groupe 3 — "Brand" (défensif, ~10 %)

- **Search Match : OFF** · **Exact** · **Enchère max par défaut : 0,30 €**

**Mots-clés à coller :**

```
radical qr
radical qr code
radicalsolution
radical qr generator
```

---

## 🚫 Mots-clés négatifs (niveau CAMPAGNE — dès J1)

```
scanner
scan
scan qr
qr scanner
qr scan
reader
qr reader
read qr code
read qr
decode qr
qr decoder
free
free qr code
business card scanner
inventory
```

> `free` / `free qr code` en négatif : sur un marché cher, protège le budget des chercheurs de gratuit qui convertissent mal en Pro. (Si un jour tu veux du volume d'installs brut, tu pourras les réactiver à enchère basse.)

---

## 🖼️ Créa publicitaire

- **Par défaut** : ASA utilise ta fiche App Store US actuelle → aucune action.
- **Optionnel plus tard** : une *Custom Product Page* orientée "logo embarqué" comme variante d'annonce sur le Groupe 1.

## 🧭 Chemin exact dans searchads.apple.com (Advanced)

1. **Campaigns → Create Campaign** → app Radical QR.
2. **Countries or Regions → United States.** Type : *Search results*.
3. **Budget** : 1,70 €/jour.
4. Premier **Ad Group** : `Exact – Intent`, Search Match **OFF**, default max CPT 0,75 €.
5. **Keywords** : colle la liste du Groupe 1 en **Exact**, ajuste les enchères clés.
6. **Save** → puis **Create Ad Group** `Discovery` (Search Match ON, 0,50 €) → **Create Ad Group** `Brand` (Exact, 0,30 €).
7. **Negative Keywords** au niveau campagne : colle la liste.
8. Vérifie les 3 groupes **actifs** → lance.

> 🔐 Attribution native ASA, **sans SDK** → ta promesse "no tracking" reste intacte.

---

## 🔁 Pilotage hebdo (vendredi, ~20 min)

1. **Search Terms report** (Discovery) → terme converti à bas coût → **passe-le en Exact** (Groupe 1).
2. Termes qui dépensent sans convertir → **négatif**.
3. **CPI par mot-clé** : < 0,60 € → **+20 %** d'enchère ; > 1,20 € → **-20 %** ou pause.
4. **`qr code` générique** : surveille-le en priorité — c'est lui qui peut engloutir le budget US. Pause-le si son CPI dépasse le double des longue-traîne.
5. Budget non consommé → enchères trop basses (marché cher) → monte-les.
6. Note les chiffres dans le tableau KPI de `HANDOFF.md`.

## 📈 Paliers de décision

| Après 2-4 semaines | Action |
|---|---|
| CPI < 0,70 € et budget consommé | 🚀 Monte à 100-150 €/mois, puis envisage un 2e marché (UK/CA anglophones, ou FR via `05`) |
| CPI 0,70-1,20 € | ✅ Continue, resserre sur les mots-clés qui convertissent, coupe le reste |
| CPI > 1,20 € malgré optim | 🔧 Réduis aux 3-4 meilleurs longue-traîne OU retravaille l'ASO en-US ; le générique `qr code` est probablement le coupable |
| Budget non consommé | ⬆️ Monte les enchères (le marché US est aux enchères hautes) |

## ✅ Checklist de lancement

- [ ] Go/no-go validé (ASO en-US + compte + paiement)
- [ ] Campagne `RadicalQR – US – Search` créée, United States, 1,70 €/j
- [ ] Groupe "Exact – Intent" + mots-clés collés en Exact + enchères clés ajustées
- [ ] Groupe "Discovery" (Search Match ON, 0,50 €)
- [ ] Groupe "Brand" (Exact, 0,30 €)
- [ ] Négatifs collés au niveau campagne
- [ ] 3 groupes actifs, campagne lancée
- [ ] Rappel vendredi posé
