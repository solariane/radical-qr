# One-time App Store setup

Steps to do **once** per app, before the first submission. After that, everything
else is scriptable.

## 1. Create the app record in App Store Connect

App Store Connect does not expose app creation via API — it's web-UI only.

1. [App Store Connect](https://appstoreconnect.apple.com) → **My Apps** → **+** → **New App**
2. Fill:
   - Platforms: **iOS** + **macOS**
   - Bundle ID: `radicalsolution.com.Radical-QR` (must match Xcode exactly)
   - Primary language: choose your source — `English (U.S.)` recommended
   - SKU: `radical-qr-001` (internal identifier, any string)
   - Name: `Radical QR`
3. **Primary category**: Utilities / **Secondary**: Productivity

## 2. Enable Xcode capabilities

Open the Xcode project → select the **Radical QR** target → **Signing & Capabilities**.

### Required

- **In-App Purchase** (for the Pro unlock)
- **App Sandbox** (already on for macOS)

### For iCloud history sync (Pro feature)

Click **+ Capability** → **iCloud** → then in the iCloud panel:
- Check the **CloudKit** box
- Under **Containers**, click **+** and create a custom container named exactly:
  ```
  iCloud.radicalsolution.com.Radical-QR
  ```
  This is the identifier referenced by `RadicalQRApp.swift` in the `ModelConfiguration`.

Xcode will auto-generate the required entitlements and register the container
with Apple. Wait a few minutes after enabling — the container needs to propagate
to CloudKit's servers before the first sync succeeds.

### Do NOT enable

- Push Notifications, Sign In with Apple, Associated Domains, Siri, App Attest,
  Personal VPN, HealthKit, HomeKit, Background Modes, Maps, Wireless Accessory,
  Access WiFi Info, NFC…
- None of them apply to a privacy-first QR generator. Keeping the capability
  list lean is actually a plus for App Review.

## 3. Create the IAP via the script

Once the app record exists, run:

```bash
./createIAP.sh
```

This hits the App Store Connect API and creates the `com.radicalsolution.radicalqr.pro`
non-consumable IAP with EN/FR localizations. You'll still need to set the
**price tier** and upload the **review screenshot** manually in ASC web UI
(Apple doesn't expose those cleanly via API).

## 4. Fill app privacy

**App Privacy** → *Data Types Collected* → check **"We don't collect data from
this app"**. This is both honest and in line with the whole pitch.

## 5. Generate the ASC API key

**Users and Access** → **Integrations** → **App Store Connect API** → **+**
- Name: `Radical QR CI`
- Access: **App Manager**
- Download the `.p8` (single download — store safely outside the repo)
- Note the **Key ID** + **Issuer ID**

Populate `.env` at the repo parent:

```env
ASC_ISSUER_ID=<uuid>
ASC_KEY_ID=<10-char>
ASC_KEY_PATH=~/.appstoreconnect/AuthKey_XXXXXXXXXX.p8
```

## 6. First build upload

```
Xcode → Product → Archive → Distribute App → App Store Connect
```

Wait ~15–30 min for processing. The build will then appear in TestFlight and
be selectable on the v1.0 version page.

## 7. Fill metadata + screenshots

- Text metadata: `./updAppStore.sh` (once DeepL is back up)
- Screenshots: drag-drop the PNGs from `appstore/screenshots/out/` into the
  ASC web UI (11 screens: 6 iPhone + 5 Mac)

## 8. Submit for review

Final check: paywall is testable from the StoreKit config during dev;
production will use the real IAP created in step 3.

Click **Submit for Review** in App Store Connect. Typical review time: 24–48h.
