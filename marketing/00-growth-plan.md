# Plan de croissance — Radical QR

> Stratégie sociale/growth. Point de départ : juillet 2026.
> Profil founder : solo · **1-2 h/semaine** · contenu **faceless** · budget paid **100-150 €/mois**.

## Diagnostic

- Baseline propre (RadicalQR seul, 90 j au 1 sept 2026) : **40 téléchargements, 4 achats Pro** → conversion install→Pro **~10 %**. Run-rate ~13-15 installs/mois, +233 % vs trimestre précédent. Détail chiffré dans [`HANDOFF.md`](HANDOFF.md).
- Ce chiffre est **excellent** pour un utilitaire (marché : 1-5 %).
- **Conclusion : le problème n'est pas la monétisation, c'est le volume en haut du funnel.** Toute la stratégie vise à faire entrer plus de monde.

## Principe directeur : l'argent remplace le temps

Vu le peu de temps dispo, la hiérarchie de ROI est :

```
ASO (gratuit, fondation)  →  Apple Search Ads (moteur payant, 20 min/sem)  →  actions ponctuelles gratuites (Product Hunt, banque vidéo)
```

On **abandonne** la cadence de contenu quotidien (pas tenable en 1-2 h/sem). On le remplace par :
- une **banque de vidéos produite en 1 session** puis programmée,
- **Apple Search Ads** qui tourne 24/7 sans intervention.

## Répartition du temps (1-2 h/semaine)

| Priorité | Activité | Temps |
|---|---|---|
| 🥇 | ASO (setup une fois, puis retouches) | 45 min au début → 15 min |
| 🥈 | Apple Search Ads (pilotage) | 20 min/sem |
| 🥉 | Revue KPI | 15 min/sem |
| Bonus | Product Hunt + banque vidéo | ponctuels |

## KPI (framework AARRR)

**North Star Metric = achats Pro / mois.**

**Les 2 KPI leviers à surveiller** :
1. **CVR fiche** (page view → install) : cible ≥ 25 %, puis 30 %. Mesure la qualité de la fiche.
2. **CPI** (coût par install, Apple Search Ads) : cible < 1 €, idéal < 0,50 €.

| Étape | Métrique | Baseline (installs/mois) | M+1 | M+3 |
|---|---|---|---|---|
| Acquisition | Installs / mois | ~13-15 | 50 | 180 |
| Acquisition | CVR fiche | ? | ≥25 % | ≥30 % |
| Revenue | Achats Pro / mois | ~1-1,5 | 5 | 18 |
| Revenue | Conv. install→Pro | ~10 % | ≥8 % | ≥10 % |

> ⚠️ **Analytics** : App Store Connect natif UNIQUEMENT. **Jamais** de SDK de tracking (Firebase/FB) — ça détruirait le positionnement "no tracking" qui est l'argument marketing n°1.

## Les 3 leviers détaillés

- **(a) ASO** → voir [`01-aso-audit.md`](01-aso-audit.md)
- **(b) Vidéos faceless** → voir [`02-video-scripts.md`](02-video-scripts.md)
- **(c) Apple Search Ads** → voir [`03-apple-search-ads.md`](03-apple-search-ads.md)

## Actions ponctuelles gratuites (pas de cadence)

- **Product Hunt** : une seule cartouche. Angle *« Radical QR — Beautiful QR codes, zero tracking »*. GIF de démo (recyclé de la banque vidéo) + 4 visuels. Poste mardi/mercredi 00:01 PST. Bonus : backlink SEO pour radicalsolution.com.
- **Comptes RS** : @radicalsolution ou @radicalqr sur TikTok + Instagram (2 max au départ). Réserve les handles ailleurs (YouTube, X, Reddit) pour protéger la marque.
- **Annuaires** : AlternativeTo, indie app directories.

## Ce qu'il ne faut PAS faire

- ❌ SDK de tracking « pour mesurer ».
- ❌ Boosts payants Instagram/TikTok (≠ Apple Search Ads) → trafic non-intentionnel.
- ❌ Lancer sur 5 réseaux à la fois en solo.
- ❌ Envoyer du trafic payant avant d'avoir une CVR fiche ≥ 25 %.
