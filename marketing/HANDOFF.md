# HANDOFF — reprise marketing Radical QR

> **Lis ce fichier en premier quand tu reviens.** Il dit où on en est, ce qu'on a appris, et quoi faire ensuite.
> Dernière mise à jour : **2026-09-21**.

## 📉 Baseline chiffrée (point zéro avant marketing)

Source : App Store Connect, Radical QR **seul** (isolé de Phone Number Cleaner), 90 jours du 4 juin au 1 sept 2026.

| Métrique | Valeur | Note |
|---|---|---|
| Téléchargements | **40** sur 90 j (~13-15/mois) | +233 % vs trimestre précédent |
| Achats Pro | **4** | ~1 vente toutes les 2-3 semaines |
| **Conversion téléchargement → Pro** | **10 %** | excellent pour un utilitaire (marché : 1-5 %) |
| Prix Pro | **4,99 € / $4.99** | achat unique |
| Revenu Pro brut | 21,63 $ sur 90 j | net ≈ 18 $ (small business 85 %) |

**Économie unitaire** : un install vaut ≈ 10 % × ~4,24 $ net ≈ **0,42 €**. Toute pub dont l'install coûte plus de ~0,80 € perd de l'argent.

> ⚠️ L'écran « Tendances 26 sem. » d'App Store Connect **agrège les 2 apps** (Radical QR + Phone Number Cleaner). La baseline ci-dessus est Radical QR seul.

## 📈 Ce que les stats de septembre ont appris

App Analytics, mi-septembre (après la V2 du 2 sept) :

| Étape | Valeur | Lecture |
|---|---|---|
| Impressions | 6 730 (**+373 %**) | l'effet « nouvelle version » : la V2 a relancé la visibilité |
| → Vues de la fiche | 130 (**1,9 %**) | ⚠️ **le goulot** : on voit l'app mais on ne clique pas |
| → Téléchargements | 46 (**+475 %**, 35 % des vues) | la fiche convertit bien |
| → Achats Pro | ~10-12 % | la monétisation marche |

**Leçons** : la croissance vient de l'**organique + des sorties de version**, pas de la pub. Le levier n°1 est le passage **impression → clic** (icône, 1er screenshot, **App Preview** qui passe en autoplay dans la recherche). Sortir une version toutes les 4-6 semaines relance la visibilité gratuitement.

## ✅ État au 2026-09-21

- [x] **Version 2.1** (texte collé → formulaires) : Mac soumis ; iOS 2.1 en préparation — **soumission par Nicolas**.
- [x] **App Previews en ligne** sur la 2.1 : iPhone 6.9″ + Mac, 2 vidéos × **en-US, fr-FR, de-DE, es-ES** (`06-app-preview-videos.md`, outillage `appstore/previews/`, envoi `node appstore-previews.mjs`).
- [x] **Correctif Mac** : les tuiles Export (4096, SVG) ne sont plus coupées en fenêtre haute (build Mac 2.1 (9)).
- [x] **Apple Search Ads USA** : lancé le 4 sept → **à mettre en pause** (voir leçons ci-dessous).
- [x] **Apple Search Ads France + Allemagne** : fichier d'import prêt (`~/Downloads/RadicalQR_FR_DE_campagnes.xlsx`, 2,50 €/j chacune, 3 groupes) + mots-clés et exclusions FR/DE — **à importer puis coller les mots-clés en Exact**.
- [x] **Test Google Search Mac** rédigé (`07-google-search-mac.md`) — **à lancer**.
- [x] Promotion croisée avec Phone Number Cleaner : déjà en place.
- [ ] **ASO non appliqué** : le sous-titre est toujours `Auto-detect. Private. Elegant.` (reco `01` : `Custom QR Maker with Logo`).
- [ ] Comptes TikTok / Instagram de la marque : à vérifier ou créer (compte **Business** sur TikTok).
- [ ] Vidéos sociales faceless (`02`) : pas encore tournées — l'outillage des App Previews peut produire les plans.
- [ ] Mémo App Previews pour Phone Number Cleaner : commité dans ce dépôt-là (`APP_PREVIEWS_MEMO.md`), session à lancer.

## 🧪 Leçons Apple Search Ads (USA, 4-20 sept)

1. **Correspondance Broad sur un terme court comme « qr »** : la moitié des impressions partait sur des **noms d'autres apps** (qoder, qring, koder, zeno, wifiman). TTR apparent 1 %.
2. **Passage en Exact** : **0 impression en une semaine**, même sur `qr code` à 1,00 €. Le marché US se paie bien plus cher — même en Broad, la pub n'était jamais sortie sur les vraies requêtes « qr code » / « qr code generator ».
3. **Conclusion** : les USA sont **trop chers pour une app à 4,99 €**. Ce n'est pas un problème de configuration. On bascule sur **FR + DE**, moins chers.
4. Les **exclusions en correspondance Large** ne bloquent pas nos mots-clés Exact (vérifié : aucun conflit sur US, FR, DE).
5. Les 0 install « attribués » des premiers jours n'étaient pas un bug : la pub n'avait tout simplement rien produit.

## 🎯 Prochaines étapes, dans l'ordre

1. **Mettre la campagne ASA US en pause.**
2. **Importer** `RadicalQR_FR_DE_campagnes.xlsx` (Apple Search Ads → import de feuille de calcul), puis **coller les mots-clés en Exact** et les **exclusions au niveau campagne** (listes dans la conversation du 21 sept ; FR aussi dans `05-campaign-setup-FR.md`).
3. **Lancer le test Google Search Mac** (`07`) avec le lien de campagne App Store.
4. **Appliquer l'ASO** (sous-titre) avec la prochaine version.
5. **Fin sept** : bilan ASA FR/DE + Google Mac (rappel planifié le **28 sept**).

## 📊 Suivi hebdomadaire (vendredi, ~20 min)

Sources : App Store Connect (Analyses de l'app, dont **Campagnes** pour les liens `ct=`), Apple Search Ads, Google Ads. Aucun SDK.

| Semaine | Installs | Impr. → vues fiche | Achats Pro | Dépense ASA FR/DE | Dépense Google Mac | Coût/install | Notes |
|---|---|---|---|---|---|---|---|
| Baseline (juin-août) | ~13-15/mois | ? | 4 / 90 j | 0 € | 0 € | — | organique pur |
| Mi-sept (V2) | 46 / période | 1,9 % | ~10-12 % | — | — | — | effet version |
| S39 (21-27 sept) | | | | | | | FR/DE + Google lancés |
| S40 | | | | | | | |
| S41 | | | | | | | |

**Seuils** : coût par install < 0,80 € (idéal < 0,50 €) → garder / monter ; > 1 € → couper. North Star = achats Pro/mois.

## 📁 Les documents

| Fichier | Contenu |
|---|---|
| [`00-growth-plan.md`](00-growth-plan.md) | Stratégie globale + KPI |
| [`01-aso-audit.md`](01-aso-audit.md) | Audit de la fiche App Store + textes prêts à coller |
| [`02-video-scripts.md`](02-video-scripts.md) | 10 storyboards de vidéos sociales faceless |
| [`03-apple-search-ads.md`](03-apple-search-ads.md) | Structure Apple Search Ads (référence) |
| [`04-campaign-setup-US.md`](04-campaign-setup-US.md) | Runbook USA — **abandonné** (trop cher), gardé pour mémoire |
| [`05-campaign-setup-FR.md`](05-campaign-setup-FR.md) | Runbook France — base des campagnes FR/DE |
| [`06-app-preview-videos.md`](06-app-preview-videos.md) | App Previews : storyboards, specs, état (en ligne) |
| [`07-google-search-mac.md`](07-google-search-mac.md) | Test Google Search pour la version Mac |
| `../appstore/previews/` | Outillage de tournage et de montage des App Previews (iPhone + Mac) |

## 🔑 Outils / accès

- **App Store Connect** : analytics, liens de campagne, métadonnées (`./updAppStore.sh`), App Previews (`node appstore-previews.mjs`) ; identifiants dans `../.env`.
- **Apple Search Ads Advanced** : searchads.apple.com.
- **Google Ads** : pour le test Mac.
- **TikTok** : compte Business, planificateur intégré (l'API de publication exige un audit TikTok ; sans audit, les vidéos restent privées).
- **Mac, mode automatisation** : toujours actif après le tournage des vidéos Mac → `sudo automationmodetool disable-automationmode-without-authentication`.

## 💡 Idée notée

- Demander une note App Store toutes les X générations de QR (mémoire `idea-appstore-rating-prompt`) : meilleure note → meilleur taux de clic et de conversion.
