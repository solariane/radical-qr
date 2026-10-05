# (c-quater) Google Search — test pour la version Mac

> **Pourquoi Google et pourquoi le Mac** : Apple Search Ads ne diffuse pas sur le **Mac App Store**. Quelqu'un qui tape « qr code generator mac » sur Google a une vraie intention d'app Mac, avec moins de concurrence que sur « qr code generator » (dominé par des sites gratuits).
> **Test borné** : ~50 € sur 3 semaines. **Stop** si un install coûte plus de ~1 € (valeur d'un install ≈ 0,60 € à 60 jours, révisée le 29 sept, cf. `HANDOFF.md`).

## Réglages de la campagne

| Réglage | Valeur |
|---|---|
| Type | **Réseau de Recherche** uniquement (décocher Partenaires du Réseau de Recherche et Réseau Display) |
| Objectif | Trafic vers le site Web (sans objectif de conversion Google) |
| Nom | `RadicalQR – Mac – Search – EN` |
| Pays | États-Unis, Royaume-Uni, Canada, Australie |
| Langue | Anglais |
| **Appareils** | **Ordinateurs uniquement** : ajustement −100 % sur mobiles et tablettes |
| Budget | **2,50 €/jour** (≈ 50 € sur 3 semaines) |
| Enchères | **CPC manuel**, 0,60 € par défaut (ou « Maximiser les clics » avec un plafond de CPC à 0,80 €) |
| URL finale | le lien de campagne App Store ci-dessous |

> Google Search ne permet pas de cibler le système d'exploitation : on filtre par « ordinateurs » + le mot « mac » dans les mots-clés.

## Mots-clés (groupe « Mac – Intent »)

Expression exacte `"…"` et mot clé exact `[…]` :

```
[qr code generator mac]
"qr code generator for mac"
"qr code maker mac"
"mac qr code app"
"qr code app for mac"
"create qr code on mac"
"make qr code on mac"
"qr code generator macos"
"qr code with logo mac"
"mac app qr code"
```

Petit second groupe « Vector » (intention pro, pas spécifique Mac — enchère plus basse, 0,40 €) :

```
"svg qr code generator"
"vector qr code generator"
"qr code svg export"
```

## Mots clés à exclure (niveau campagne)

La plupart des chercheurs Google veulent un **site gratuit** : il faut les écarter.

```
free
online
web
website
windows
pc
android
chrome
extension
scanner
scan
reader
read
excel
word
sheets
python
javascript
api
github
npm
library
```

## Annonce responsive (anglais)

**Titres** (≤ 30 caractères, vérifiés) :
1. QR Code Generator for Mac
2. Native Mac QR Code Maker
3. Right-Click Any Link for a QR
4. Your Logo in the QR Code
5. Export SVG, PDF & PNG
6. Vector QR Codes, Print Ready
7. No Tracking. No Account.
8. Everything Stays on Your Mac
9. One-Time Purchase, No Sub
10. Paste Text, Get the Right QR
11. Wi-Fi, vCard & Event QR Codes
12. Round Dots, Custom Gradients
13. Made for macOS
14. Radical QR for Mac
15. On the Mac App Store

Épingler le titre 1 en position 1 pour garder « for Mac » toujours visible.

**Descriptions** (≤ 90 caractères, vérifiées) :
1. Paste a link, a Wi-Fi card or an email signature: Radical QR builds the right QR code.
2. Add your logo, round the dots, pick gradients. Export print-ready SVG, PDF or PNG.
3. Right-click a link in Safari, choose Generate QR Code. Native, fast and fully private.
4. No tracking, no account, no subscription. Free to try, Pro is a one-time purchase.

**Chemin affiché** : `apps.apple.com / mac`

## Mesure sans SDK : lien de campagne App Store

1. App Store Connect → **Analyses de l'app** → Radical QR → **Campagnes** → « Générer un lien de campagne ».
2. Nom de campagne : `google-mac-en`. On obtient un lien de la forme
   `https://apps.apple.com/app/apple-store/id6763236391?pt=<ton_provider_token>&ct=google-mac-en&mt=8`
3. Mettre ce lien comme **URL finale** de l'annonce (remplacer `mt=8` par `mt=12`, qui désigne le Mac App Store, si le lien généré le contient).
4. Les installs apparaissent dans Analyses de l'app → Sources → **Campagnes**, sans aucun code dans l'app.

> ⚠️ À vérifier au lancement : que les installs du **Mac** App Store remontent bien par campagne dans App Analytics. Sinon, repli : pointer l'annonce vers la page radicalsolution.com et compter les clics vers l'App Store.

## Pilotage (10 min/semaine)

- **Termes de recherche** (Google Ads → Mots clés → Termes de recherche) : exclure tout ce qui est gratuit, en ligne, Windows ou « scanner ».
- **CPC moyen** > 0,80 € → baisser les enchères ; **0 impression** → les monter de 20 %.
- Après 3 semaines : installs (App Analytics → Campagnes) ÷ dépense. **> 1 € par install → on coupe.**
