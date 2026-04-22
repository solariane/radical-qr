#!/usr/bin/env node
/**
 * appstore-iap-create.mjs
 *
 * Creates (or updates) the `Radical QR Pro` non-consumable IAP in App Store
 * Connect, with per-locale name + description. Idempotent — running it twice
 * is safe; it PATCHes instead of POSTing on the second run.
 *
 * What this script does:
 *   1. Look up the app by bundle id
 *   2. Look up or create the IAP (v2 endpoint) with the productId
 *   3. Create / patch localizations for each locale in pro.json
 *
 * What it does NOT do (Apple doesn't expose these cleanly):
 *   - Set the price tier (use ASC web UI → In-App Purchases → price)
 *   - Upload the review screenshot (use ASC web UI → "App Review Information")
 *   - Submit for review (handled with the app version submission)
 *
 * Required environment (same as appstore-push.mjs):
 *   ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH
 *
 * Usage:
 *   node appstore-iap-create.mjs [--bundle-id=...] [--dry-run] [--iap=path/to/pro.json]
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

// --- CLI ------------------------------------------------------------------

const args = Object.fromEntries(
  process.argv.slice(2).flatMap((a) => {
    if (a.startsWith("--")) {
      const eq = a.indexOf("=");
      return eq === -1 ? [[a.slice(2), true]] : [[a.slice(2, eq), a.slice(eq + 1)]];
    }
    return [];
  })
);

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const IAP_PATH = args.iap
  ? path.resolve(args.iap)
  : path.join(SCRIPT_DIR, "appstore", "iap", "pro.json");

const iap = JSON.parse(fs.readFileSync(IAP_PATH, "utf8"));
const appConfig = JSON.parse(fs.readFileSync(path.join(SCRIPT_DIR, "appstore", "config.json"), "utf8"));
const BUNDLE_ID = args["bundle-id"] || appConfig.bundleID;
const DRY_RUN = Boolean(args["dry-run"]);

const ISSUER_ID = process.env.ASC_ISSUER_ID;
const KEY_ID = process.env.ASC_KEY_ID;
let KEY_PATH = process.env.ASC_KEY_PATH;
if (KEY_PATH?.startsWith("~/")) KEY_PATH = path.join(os.homedir(), KEY_PATH.slice(2));

if (!ISSUER_ID || !KEY_ID || !KEY_PATH) {
  console.error(`Error: App Store Connect credentials missing.
  Set in .env or environment:
    ASC_ISSUER_ID=<uuid>
    ASC_KEY_ID=<10-char-key-id>
    ASC_KEY_PATH=<path-to-AuthKey_KEYID.p8>`);
  process.exit(1);
}
if (!fs.existsSync(KEY_PATH)) {
  console.error(`Error: ASC_KEY_PATH does not exist: ${KEY_PATH}`);
  process.exit(1);
}

// --- Logging --------------------------------------------------------------

const COL = { red: "\x1b[31m", green: "\x1b[32m", yellow: "\x1b[33m", cyan: "\x1b[36m", magenta: "\x1b[35m", reset: "\x1b[0m", dim: "\x1b[2m" };
const step = (m) => console.log(`\n${COL.magenta}> ${m}${COL.reset}`);
const ok = (m) => console.log(`  ${COL.green}+ ${m}${COL.reset}`);
const warn = (m) => console.log(`  ${COL.yellow}! ${m}${COL.reset}`);
const info = (m) => console.log(`  ${COL.cyan}i ${m}${COL.reset}`);
const dim = (m) => console.log(`  ${COL.dim}${m}${COL.reset}`);
const fail = (m) => { console.error(`${COL.red}Error: ${m}${COL.reset}`); process.exit(1); };

// --- JWT (ES256) ----------------------------------------------------------

function b64url(buf) {
  return Buffer.from(buf).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function signJWT() {
  const header = { alg: "ES256", kid: KEY_ID, typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: ISSUER_ID, iat: now, exp: now + 1200, aud: "appstoreconnect-v1" };
  const signingInput = `${b64url(JSON.stringify(header))}.${b64url(JSON.stringify(payload))}`;
  const pk = fs.readFileSync(KEY_PATH, "utf8");
  const signer = crypto.createSign("SHA256");
  signer.update(signingInput);
  signer.end();
  const sig = signer.sign({ key: pk, dsaEncoding: "ieee-p1363" });
  return `${signingInput}.${b64url(sig)}`;
}

// --- API client -----------------------------------------------------------

const API = "https://api.appstoreconnect.apple.com";
let token = null;

async function asc(pathname, { method = "GET", body = null } = {}) {
  token ??= signJWT();
  const url = pathname.startsWith("http") ? pathname : `${API}${pathname}`;
  const headers = { "Authorization": `Bearer ${token}` };
  let reqBody = null;
  if (body) {
    headers["Content-Type"] = "application/json";
    reqBody = JSON.stringify(body);
  }
  const res = await fetch(url, { method, headers, body: reqBody });
  const text = await res.text();
  let json = null;
  try { json = text ? JSON.parse(text) : null; } catch { /* ignore */ }
  if (!res.ok) {
    const err = json?.errors?.[0];
    fail(`ASC ${method} ${pathname} → HTTP ${res.status}${err ? `\n  ${err.title}: ${err.detail}` : `\n  ${text}`}`);
  }
  return json;
}

// --- Main -----------------------------------------------------------------

async function main() {
  step(`Fetching app record for bundle id: ${BUNDLE_ID}`);
  const appRes = await asc(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&limit=1`);
  const app = appRes?.data?.[0];
  if (!app) fail(`No app found with bundle id ${BUNDLE_ID}. Create it in App Store Connect first (see appstore/SETUP.md).`);
  const appId = app.id;
  ok(`App id: ${appId}`);

  step(`Looking up existing IAPs on this app...`);
  // v2 endpoint for modern IAPs (non-subscription)
  const iapsRes = await asc(`/v1/apps/${appId}/inAppPurchasesV2?limit=200`);
  const existing = (iapsRes?.data ?? []).find((p) => p.attributes?.productId === iap.productId);
  let iapId;

  if (existing) {
    iapId = existing.id;
    info(`Found existing IAP (${iap.productId}) → id: ${iapId}, state: ${existing.attributes?.state}`);

    // Patch metadata in case name/review note changed
    if (!DRY_RUN) {
      await asc(`/v2/inAppPurchases/${iapId}`, {
        method: "PATCH",
        body: {
          data: {
            type: "inAppPurchases",
            id: iapId,
            attributes: {
              name: iap.referenceName,
              familyShareable: Boolean(iap.familyShareable),
              reviewNote: iap.reviewNote ?? "",
            },
          },
        },
      });
      ok(`Updated IAP ${iap.productId}`);
    } else {
      info(`(dry-run) would PATCH IAP ${iap.productId}`);
    }
  } else {
    step(`Creating new IAP ${iap.productId}...`);
    if (DRY_RUN) {
      info(`(dry-run) would POST new IAP (productId=${iap.productId}, type=${iap.type})`);
    } else {
      const createRes = await asc(`/v2/inAppPurchases`, {
        method: "POST",
        body: {
          data: {
            type: "inAppPurchases",
            attributes: {
              name: iap.referenceName,
              productId: iap.productId,
              inAppPurchaseType: iap.type,  // e.g. NON_CONSUMABLE
              familyShareable: Boolean(iap.familyShareable),
              reviewNote: iap.reviewNote ?? "",
            },
            relationships: {
              app: { data: { type: "apps", id: appId } },
            },
          },
        },
      });
      iapId = createRes?.data?.id;
      if (!iapId) fail("IAP created but no id returned?");
      ok(`Created IAP id: ${iapId}`);
    }
  }

  if (DRY_RUN && !iapId) {
    warn("Dry-run: IAP wasn't created so can't touch localizations. Run without --dry-run to proceed.");
    return;
  }

  // --- Localizations -------------------------------------------------------

  step(`Fetching existing localizations...`);
  const locsRes = await asc(`/v2/inAppPurchases/${iapId}/inAppPurchaseLocalizations?limit=200`);
  const existingLocs = new Map();
  for (const l of locsRes?.data ?? []) {
    existingLocs.set(l.attributes?.locale, l);
  }
  info(`IAP has ${existingLocs.size} localization(s).`);

  for (const [locale, copy] of Object.entries(iap.localizations)) {
    const existing = existingLocs.get(locale);
    const attrs = { name: copy.name, description: copy.description };

    if (DRY_RUN) {
      info(`(dry-run) would ${existing ? "PATCH" : "CREATE"} ${locale}: "${copy.name}"`);
      continue;
    }

    if (existing) {
      await asc(`/v1/inAppPurchaseLocalizations/${existing.id}`, {
        method: "PATCH",
        body: {
          data: {
            type: "inAppPurchaseLocalizations",
            id: existing.id,
            attributes: attrs,
          },
        },
      });
      ok(`Updated ${locale}: "${copy.name}"`);
    } else {
      await asc(`/v1/inAppPurchaseLocalizations`, {
        method: "POST",
        body: {
          data: {
            type: "inAppPurchaseLocalizations",
            attributes: { ...attrs, locale },
            relationships: {
              inAppPurchaseV2: { data: { type: "inAppPurchases", id: iapId } },
            },
          },
        },
      });
      ok(`Created ${locale}: "${copy.name}"`);
    }
  }

  // --- Remaining manual steps ---------------------------------------------

  step("Next steps (manual — Apple doesn't expose these cleanly via API):");
  console.log(`
  ${COL.cyan}1. Price tier${COL.reset}
     App Store Connect → My Apps → Radical QR → In-App Purchases → ${iap.productId} → Pricing
     Suggested: Tier 5 (≈ 4.99 €)

  ${COL.cyan}2. Review screenshot${COL.reset}
     Upload a screenshot of the paywall screen under "App Review Information"
     for this IAP. The app screenshot showing the "Get Pro" button is perfect.

  ${COL.cyan}3. Submit${COL.reset}
     The IAP goes through review together with the app version. No separate
     submission step — just make sure it's attached to v1.0.
  `);
}

main().catch((e) => { console.error(e); process.exit(1); });
