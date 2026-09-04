# (c-ter) Runbook Apple Search Ads — FRANCE (marché SECONDAIRE, à lancer plus tard)

> ⚠️ **La France n'est pas le marché prioritaire.** Le marché n°1 est les USA → voir `04-campaign-setup-US.md`.
> Ne lance cette campagne France **qu'après** que les USA soient rentables (cf. paliers de décision du doc `04`), ou en parallèle si tu montes le budget global.
> Version **exécutable** de `03-apple-search-ads.md`, calibrée sur **50 €/mois**.
> Le doc `03` reste la référence stratégique ; **pour le budget 50 € sur la France, ce sont les chiffres ci-dessous qui font foi.**
> Outil : **Apple Search Ads Advanced** (searchads.apple.com) — gratuit, contrôle fin. PAS "Basic".
> App : Radical QR : Générateur QR — Apple ID `6763236391`.

## ⚠️ Avant de lancer (go / no-go)

1. [ ] **ASO appliqué** (sous-titre + keywords de `01-aso-audit.md`) — sinon tu paies pour une fiche non optimisée.
2. [ ] **CVR fiche vérifiée** dans App Store Connect. Idéal ≥ 25 %. Si tu ne l'as pas encore, lance quand même en surveillant le CPI de près.
3. [ ] Compte Apple Search Ads **Advanced** créé + moyen de paiement.
4. [ ] Rappel hebdo vendredi posé (pilotage 20 min).

## 💶 La math du budget

- 50 €/mois = **~1,70 €/jour** de budget campagne.
- Seuil de rentabilité (rappel) : valeur d'un install ≈ 10 % × 4,24 € net ≈ **0,42 €** → vise **CPI < 0,50 €**, tolérable jusqu'à ~0,80 €.
- **Concentration = signal.** À 1,70 €/j, on ne s'éparpille PAS sur plusieurs pays. **France uniquement** au départ pour obtenir des données lisibles vite. (Les USA / DE / ES viendront quand la France est rentable — cf. paliers plus bas.)

## 🏗️ Structure à créer

**1 seule campagne**, 3 groupes de pub. Le budget est partagé au niveau campagne (ASA n'a pas de budget par groupe) — on **pilote la répartition par les enchères** : les groupes qui comptent enchérissent plus haut.

```
Campagne : "RadicalQR – FR – Search"
├── Groupe 1 : "Exact – Generic"   (Search Match OFF, mots-clés exacts)   ← le cœur
├── Groupe 2 : "Discovery"         (Search Match ON, découverte)          ← exploration
└── Groupe 3 : "Brand"             (Search Match OFF, marque, défensif)   ← quasi gratuit
```

### Réglages campagne (à recopier)

| Champ | Valeur |
|---|---|
| Nom | `RadicalQR – FR – Search` |
| App | Radical QR : Générateur QR |
| Pays / région | **France** uniquement |
| Budget quotidien | **1,70 €** |
| Plafond quotidien (daily cap) | laisser vide (le budget quotidien suffit) |
| Dates | Début aujourd'hui, pas de date de fin |

---

## 🎯 Groupe 1 — "Exact – Generic" (le cœur, ~70 % du budget visé)

- **Search Match : OFF**
- **Type de correspondance : Exact** pour tous les mots-clés
- **Enchère max par défaut (default max CPT) : 0,55 €** (ajuste selon la fourchette suggérée par Apple)
- Audience : tout par défaut (ne restreins RIEN au début — pas assez de volume pour segmenter)

**Mots-clés à coller (ASA permet l'ajout en masse — colle la liste, mets tout en Exact) :**

```
qr code
générateur qr
générateur de qr code
générateur code qr
créer qr code
créer un qr code
faire un qr code
qr code personnalisé
qr code logo
qr code avec logo
code qr
qr code wifi
qr code vcard
```

**Enchères de départ suggérées** (tu peux affiner par mot-clé après l'ajout global) :

| Mot-clé | Enchère max | Pourquoi |
|---|---|---|
| `qr code logo` / `qr code avec logo` | **0,65 €** | Intention Pro maximale (le logo = feature payante n°1) |
| `qr code personnalisé` | 0,60 € | Forte intention de perso → Pro |
| `qr code` / `code qr` | 0,55 € | Gros volume mais générique, surveille le CPI |
| `générateur qr` / `créer qr code` / variantes | 0,55 € | Cœur d'intention "je veux en créer un" |
| `qr code wifi` / `qr code vcard` | 0,45 € | Longue-traîne pas chère, bon usage |

> ⚠️ **`qr code gratuit` volontairement exclu** de la liste : ça attire des chercheurs de gratuit qui ne passent pas Pro. (On le met même en négatif plus bas.) Si tu veux du volume d'installs pur, tu peux le rajouter à 0,35 € — mais attends-toi à une conversion plus basse.

---

## 🔍 Groupe 2 — "Discovery" (exploration, ~20 % visé)

- **Search Match : ON** (c'est tout l'intérêt — Apple matche automatiquement des requêtes que tu n'as pas listées)
- Pas de mots-clés à ajouter (Search Match s'en charge)
- **Enchère max par défaut : 0,40 €** (plus basse que l'Exact → le cœur garde la priorité budget)
- Rôle : **machine à trouver des mots-clés pas chers**. Chaque vendredi tu récoltes les bons termes ici → tu les passes en Exact dans le Groupe 1.

---

## 🛡️ Groupe 3 — "Brand" (défensif, ~10 %, coûte presque rien)

- **Search Match : OFF**, correspondance **Exact**
- **Enchère max par défaut : 0,30 €** (tu gagnes tes propres termes pour presque rien)
- Rôle : empêcher un concurrent d'apparaître quand quelqu'un cherche ton app par son nom.

**Mots-clés à coller :**

```
radical qr
radical qr code
générateur radical qr
radicalsolution
```

---

## 🚫 Mots-clés négatifs (au niveau CAMPAGNE — à mettre dès J1)

Empêche de brûler le budget sur des requêtes de gens qui veulent **scanner/lire** (ton app ne fait que générer) ou du gratuit non-convertissant.

```
scanner
scan
scanner qr
qr scanner
lecteur
lecteur qr
lire qr code
lire un qr code
reader
qr reader
décoder qr
décodeur qr
gratuit
qr code gratuit
business card scanner
inventaire
```

> Rappel de la logique inversée vs l'ASO : en **keyword ASO** on tolérait "scan" pour le volume d'indexation ; en **paid** on le met en **négatif**, parce qu'ici chaque clic coûte et un chercheur de "scanner" ne convertira pas.

---

## 🖼️ Créa publicitaire

- **Par défaut** : ASA utilise ta fiche App Store actuelle (ton screenshot #1 + titre). **Aucune action requise** → commence comme ça.
- **Optionnel (plus tard)** : crée une *Custom Product Page* dans App Store Connect (ex. une page qui met le **logo embarqué** en avant) et utilise-la comme variante d'annonce sur le groupe "Exact – Generic". Ça peut booster le tap-through. À tester une fois que la base tourne.

## 🧭 Le chemin exact dans searchads.apple.com (Advanced)

1. **Campaigns → Create Campaign** → choisis l'app Radical QR.
2. **Countries or Regions → France.** Type : *Search results*.
3. **Budget** : 1,70 €/jour. (Pas de daily cap.)
4. **Ad Group** (le premier) : nomme-le `Exact – Generic`, Search Match **OFF**, default max CPT 0,55 €.
5. **Keywords** : colle la liste du Groupe 1, passe tout en **Exact**, ajuste les enchères clés.
6. **Save**. Puis dans la campagne : **Create Ad Group** → `Discovery` (Search Match ON, 0,40 €) ; **Create Ad Group** → `Brand` (Exact, 0,30 €, colle les termes de marque).
7. **Negative Keywords** : au niveau campagne, colle la liste des négatifs.
8. Vérifie que les 3 groupes sont **actifs** et lance.

> 🔐 Attribution : ASA mesure les installs **nativement, sans SDK** → aucune entorse à ta promesse "no tracking". Rien à installer dans l'app.

---

## 🔁 Pilotage hebdo (vendredi, ~20 min)

1. **Search Terms report** (groupe Discovery) → un terme a converti à bas coût ? → **passe-le en Exact** dans le Groupe 1.
2. **Termes qui dépensent sans convertir** → **ajoute-les en négatif**.
3. **CPI par mot-clé** :
   - < 0,40 € → **monte l'enchère +20 %** (prends plus de volume).
   - > 0,80 € → **baisse -20 %** ou mets en pause.
4. **Budget consommé ?** Si tu ne dépenses pas tes 1,70 €/j → enchères trop basses (tu perds les enchères) → monte-les. Si tu satures tôt chaque jour → tout va bien, tu peux monter le budget si le CPI est bon.
5. **Note les chiffres** dans le tableau KPI de `HANDOFF.md`.

## 📈 Paliers de décision

| Après 2-4 semaines | Action |
|---|---|
| CPI < 0,50 € et budget consommé | 🚀 Monte à 100-150 €/mois (3-5 €/j) et/ou ouvre un 2e pays (US ou DE) |
| CPI 0,50-0,80 € | ✅ Continue, optimise mots-clés + négatifs, patiente |
| CPI > 0,80 € malgré optim | 🔧 Retravaille l'ASO (fiche/CVR) avant de dépenser plus |
| Budget non consommé | ⬆️ Enchères trop basses → augmente les max CPT |

## ✅ Checklist de lancement

- [ ] Go/no-go validé (ASO + compte + paiement)
- [ ] Campagne `RadicalQR – FR – Search` créée, France, 1,70 €/j
- [ ] Groupe "Exact – Generic" + mots-clés collés en Exact + enchères clés ajustées
- [ ] Groupe "Discovery" (Search Match ON, 0,40 €)
- [ ] Groupe "Brand" (Exact, 0,30 €) + termes de marque
- [ ] Négatifs collés au niveau campagne
- [ ] 3 groupes actifs, campagne lancée
- [ ] Rappel vendredi posé
