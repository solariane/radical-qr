# (a) Audit ASO — fiche App Store Radical QR

> Date de l'audit : 2026-07-23 · Source lue : `appstore/metadata/en-US/`
> Rappel : l'App Store indexe **le nom + le sous-titre + le champ keywords**. La description N'EST PAS indexée pour la recherche (sauf sur le nom du développeur). Donc chaque caractère du sous-titre et des keywords compte pour le référencement.

## État actuel (en-US)

| Champ | Valeur actuelle | Longueur | Limite | Verdict |
|---|---|---|---|---|
| `name` | `Radical QR: QR Code Generator` | 29 | 30 | ✅ Bon — contient le keyword fort "QR Code Generator" |
| `subtitle` | `Auto-detect. Private. Elegant.` | 30 | 30 | ⚠️ **Gaspillé en ASO** — 3 adjectifs à quasi zéro volume de recherche |
| `keywords` | `code,generator,maker,creator,logo,custom,barcode,vcard,wifi,svg,pdf,url,contact,menu,event,tracking` | 99 | 100 | ⚠️ Redondances + termes faibles |
| `description` | (bien écrite, orientée conversion) | 2094 | 4000 | ✅ RAS pour l'ASO (non indexée), bonne pour la conversion |
| `promotional_text` | (à jour, features) | 118 | 170 | ✅ OK (modifiable sans review — bon pour tester des accroches) |

## Les 3 problèmes prioritaires

### 1. Le sous-titre brûle 30 caractères indexés sur des adjectifs
`Private` et `Elegant` ne sont quasiment jamais tapés dans la recherche App Store. `Auto-detect` non plus. Le sous-titre doit **combiner mots-clés à volume + bénéfice**, pas faire de la poésie de marque.

**Options proposées (toutes ≤ 30 car.) :**

| Option | Texte | Car. | Logique |
|---|---|---|---|
| A (keyword-max) | `QR Maker: Logo, Wi-Fi, vCard` | 28 | Injecte "maker", "logo", "wifi", "vcard" — 4 termes indexés à volume |
| B (équilibrée) ✅ | `Custom QR Maker with Logo` | 25 | "custom", "maker", "logo" + lisible/pro |
| C (privacy garde) | `Private QR Maker with Logo` | 26 | Garde l'angle privacy mais ajoute "maker"+"logo" |

➡️ **Reco : Option B** (ou C si tu tiens à garder un mot "privacy" visible). On récupère "maker" et "logo" dans l'index sans perdre en clarté.

### 2. Le champ keywords répète des mots déjà dans le nom
`code` et `generator` sont **déjà dans le nom de l'app** → Apple les indexe déjà. Les répéter dans keywords = ~16 caractères gaspillés. Idem, ne jamais remettre "QR" ni "radical".

Termes faibles à retirer : `tracking` (personne ne cherche "tracking" pour créer un QR), `url`, `event` (faible volume isolé).

Termes forts manquants : `scan` (énorme volume — les gens confondent créer/scanner ; caveat ci-dessous), `business`, `sticker`, `flyer`, `poster`, `qrcode` (en un seul mot — variante de recherche distincte).

**Champ keywords proposé (99 car., sans espaces après virgules — correct) :**
```
maker,creator,logo,custom,scan,barcode,wifi,vcard,svg,pdf,business,menu,sticker,flyer,poster,qrcode
```
> ⚠️ **Caveat sur `scan`** : ton app *génère* mais ne *scanne pas* (cf. `config.json → appContext`). Mettre "scan" en keyword n'est pas un mensonge (c'est une association d'index, pas une promesse), et "qr scan" est un terme énorme. Mais si tu veux rester 100 % irréprochable, remplace `scan` par `sharing` ou `print`. **À toi de trancher.**

### 3. Cohérence multilingue = ton avantage sous-exploité
Tu as 10 locales déjà câblées via `updAppStore.sh`. Mais le champ keywords **ne se traduit pas mot-à-mot** : dans chaque langue, les gens tapent des termes différents (ex. en allemand "qr code erstellen", en espagnol "generador qr"). DeepL traduit littéralement, ce qui donne des keywords sous-optimaux hors anglais.

➡️ **Action (plus tard, pas semaine 1)** : pour tes 3-4 plus gros marchés (probables : en, fr, de, es, ja), écris les keywords **à la main** dans la langue locale plutôt que laisser DeepL. C'est là qu'est le gisement de trafic gratuit que tes concurrents solo ignorent.

## Screenshots (rappel de l'ordre)

Les 2 premiers screenshots décident ~80 % des installs (les seuls visibles sans scroller). Ordre actuel d'après les fichiers : `01-hero` → `01b-eye-styles` → `02-auto-detect` → `03-customization` → `04-logo` → `05-export` → `06-privacy`.

- ✅ #1 hero = bon.
- ⚠️ #2 = eye-styles. C'est joli mais est-ce le meilleur argument de **conversion** ? Teste `04-logo` en #2 (le logo embarqué est l'argument Pro n°1 et très démontrable). À valider par A/B via App Store Connect (Product Page Optimization, gratuit).

## Comment appliquer

Tu édites la **source de vérité** (en-US et fr-FR sont hand-written), puis le pipeline traduit + pousse :

```bash
# 1. Éditer les fichiers source
#    appstore/metadata/en-US/subtitle.txt
#    appstore/metadata/en-US/keywords.txt
#    (idem fr-FR à la main)

# 2. Dry-run pour voir ce qui changerait
./updAppStore.sh --dry-run

# 3. Traduire les locales manquantes + pousser sur ASC
./updAppStore.sh
```

> ⚠️ Le sous-titre et les keywords sont des champs **soumis à review App Store** (contrairement à `promotional_text`). Ils ne s'appliquent qu'à la prochaine version soumise. Planifie ces changements avec ta prochaine build.

## Checklist ASO (à cocher)

- [ ] Remplacer le sous-titre en-US (Option B ou C)
- [ ] Remplacer le champ keywords en-US (version 99 car.)
- [ ] Décider du sort de `scan` (garder / remplacer par `print`)
- [ ] Faire de même à la main pour fr-FR
- [ ] `./updAppStore.sh --dry-run` puis push
- [ ] Lancer un A/B test screenshot #2 (logo vs eye-styles) dans App Store Connect
- [ ] Plus tard : keywords manuels localisés pour de, es, ja
