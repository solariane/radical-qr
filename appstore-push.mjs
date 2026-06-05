#!/usr/bin/env node
/**
 * appstore-push.mjs
 *
 * Pushes localized App Store metadata from `appstore/metadata/<locale>/*.txt`
 * to App Store Connect, targeting the current EDIT version of the app.
 *
 * Uses the App Store Connect REST API directly with a JWT (ES256) signed by
 * a .p8 private key — no fastlane / Ruby dependency.
 *
 * Required environment (set in `.env` alongside DEEPL_API_KEY):
 *   ASC_ISSUER_ID       - UUID issuer from App Store Connect → Keys
 *   ASC_KEY_ID          - 10-char key id
 *   ASC_KEY_PATH        - absolute or ~-relative path to the AuthKey_<KEY_ID>.p8 file
 *
 * Usage:
 *   node appstore-push.mjs [--bundle-id=...] [--dry-run] [--only=<locale>[,<locale>...]]
 *
 * Notes:
 *   - Only pushes to the CURRENT EDITABLE version (state "PREPARE_FOR_SUBMISSION"
 *     or similar). If none exists, the script exits cleanly with instructions.
 *   - The `name` field is tracked at the app level for the primary locale —
 *     this script only updates name when it differs from what's already live.
 *     Subtitle / description / keywords / promotional_text are per-version and
 *     are always safe to update.
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

// --- Config & CLI ----------------------------------------------------------

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
const CONFIG_PATH = path.join(SCRIPT_DIR, "appstore", "config.json");
const METADATA_DIR = path.join(SCRIPT_DIR, "appstore", "metadata");

const config = JSON.parse(fs.readFileSync(CONFIG_PATH, "utf8"));
const BUNDLE_ID = args["bundle-id"] || config.bundleID;
const DRY_RUN = Boolean(args["dry-run"]);
const ONLY = typeof args.only === "string" ? new Set(args.only.split(",").map((s) => s.trim())) : null;

const ISSUER_ID = process.env.ASC_ISSUER_ID;
const KEY_ID = process.env.ASC_KEY_ID;
let KEY_PATH = process.env.ASC_KEY_PATH;
if (KEY_PATH?.startsWith("~/")) KEY_PATH = path.join(os.homedir(), KEY_PATH.slice(2));

if (!ISSUER_ID || !KEY_ID || !KEY_PATH) {
  console.error(`Error: App Store Connect credentials missing.
  Set in .env or environment:
    ASC_ISSUER_ID=<uuid>
    ASC_KEY_ID=<10-char-key-id>
    ASC_KEY_PATH=<path-to-AuthKey_KEYID.p8>
  Get these from App Store Connect → Users & Access → Keys.`);
  process.exit(1);
}
if (!fs.existsSync(KEY_PATH)) {
  console.error(`Error: ASC_KEY_PATH does not exist: ${KEY_PATH}`);
  process.exit(1);
}

// --- Colors / logging ------------------------------------------------------

const COL = { red: "\x1b[31m", green: "\x1b[32m", yellow: "\x1b[33m", cyan: "\x1b[36m", magenta: "\x1b[35m", reset: "\x1b[0m", dim: "\x1b[2m" };
const step = (m) => console.log(`\n${COL.magenta}> ${m}${COL.reset}`);
const ok = (m) => console.log(`  ${COL.green}+ ${m}${COL.reset}`);
const warn = (m) => console.log(`  ${COL.yellow}! ${m}${COL.reset}`);
const info = (m) => console.log(`  ${COL.cyan}i ${m}${COL.reset}`);
const dim = (m) => console.log(`  ${COL.dim}${m}${COL.reset}`);
const fail = (m) => { console.error(`${COL.red}Error: ${m}${COL.reset}`); process.exit(1); };

// --- JWT (ES256) -----------------------------------------------------------

function b64url(buf) {
  return Buffer.from(buf).toString("base64").replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function signJWT() {
  const header = { alg: "ES256", kid: KEY_ID, typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const payload = { iss: ISSUER_ID, iat: now, exp: now + 1200, aud: "appstoreconnect-v1" };

  const encodedHeader = b64url(JSON.stringify(header));
  const encodedPayload = b64url(JSON.stringify(payload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const pk = fs.readFileSync(KEY_PATH, "utf8");
  const signer = crypto.createSign("SHA256");
  signer.update(signingInput);
  signer.end();
  const derSig = signer.sign({ key: pk, dsaEncoding: "ieee-p1363" });
  return `${signingInput}.${b64url(derSig)}`;
}

// --- API helper ------------------------------------------------------------

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

// --- Helpers ---------------------------------------------------------------

function readMetadataField(localeDir, field) {
  const p = path.join(METADATA_DIR, localeDir, `${field}.txt`);
  if (!fs.existsSync(p)) return null;
  return fs.readFileSync(p, "utf8").replace(/\s+$/, "");
}

/**
 * Map our directory locale (e.g. "fr-FR", "zh-Hans") to the exact locale code
 * App Store Connect expects. These match; but App Store uses specific region
 * codes for some (e.g. `it` not `it-IT`), so let the dir name be authoritative.
 */
function ascLocale(dir) { return dir; }

// --- Main ------------------------------------------------------------------

async function main() {
  step(`Fetching app record for bundle id: ${BUNDLE_ID}`);
  const appRes = await asc(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&limit=1`);
  const app = appRes?.data?.[0];
  if (!app) fail(`No app found with bundle id ${BUNDLE_ID}.`);
  const appId = app.id;
  ok(`App id: ${appId}`);

  // Universal apps have one appStoreVersion per platform (IOS, MAC_OS, TV_OS).
  // Per-version metadata (description, keywords, …) must be pushed to EACH.
  step("Looking up editable App Store versions (all platforms)...");
  const versionsRes = await asc(
    `/v1/apps/${appId}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED,WAITING_FOR_REVIEW&limit=20`
  );
  const versions = versionsRes?.data ?? [];
  if (versions.length === 0) {
    warn("No editable App Store version found. Create or edit a version in App Store Connect first.");
    info("Tip: a version stays editable until it's submitted for review or accepted.");
    process.exit(0);
  }
  for (const v of versions) {
    ok(`Version id: ${v.id}  platform: ${v.attributes?.platform ?? "?"}  state: ${v.attributes?.appStoreState}  v${v.attributes?.versionString}`);
  }

  const allLocales = [
    { dir: config.sourceLocale, isHandWritten: true },
    ...config.targetLocales,
  ];

  let updated = 0, created = 0, nameUpdates = 0;

  // ---- Copyright is a per-version attribute shared across platforms -------
  const copyright = config.copyright;
  if (copyright) {
    step(`Setting copyright on all ${versions.length} version(s): "${copyright}"`);
    for (const v of versions) {
      if (v.attributes?.copyright === copyright) {
        dim(`${v.attributes?.platform}: copyright already set, skipping`);
        continue;
      }
      if (DRY_RUN) {
        info(`(dry-run) would PATCH ${v.attributes?.platform} copyright → "${copyright}"`);
      } else {
        await asc(`/v1/appStoreVersions/${v.id}`, {
          method: "PATCH",
          body: {
            data: {
              type: "appStoreVersions",
              id: v.id,
              attributes: { copyright },
            },
          },
        });
        ok(`${v.attributes?.platform}: copyright set`);
      }
    }
  }

  // ---- Push per-version metadata for EACH platform version ----------------
  for (const v of versions) {
    const versionId = v.id;
    const platform = v.attributes?.platform ?? "?";

    step(`Fetching existing localizations for ${platform} / v${v.attributes?.versionString}...`);
    const locsRes = await asc(`/v1/appStoreVersions/${versionId}/appStoreVersionLocalizations?limit=200`);
    const existingByLocale = new Map();
    for (const l of locsRes?.data ?? []) {
      existingByLocale.set(l.attributes?.locale, l);
    }
    info(`Version has ${existingByLocale.size} locale(s) currently.`);

    for (const loc of allLocales) {
      if (ONLY && !ONLY.has(loc.dir)) continue;
      const localeCode = ascLocale(loc.dir);
      const localeDir = path.join(METADATA_DIR, loc.dir);
      if (!fs.existsSync(localeDir)) { dim(`Skip ${loc.dir} (no metadata dir)`); continue; }

      const attrs = {};
      const description = readMetadataField(loc.dir, "description");
      const keywords = readMetadataField(loc.dir, "keywords");
      const promo = readMetadataField(loc.dir, "promotional_text");
      const releaseNotes = readMetadataField(loc.dir, "release_notes");
      const support = readMetadataField(loc.dir, "support_url");
      const marketing = readMetadataField(loc.dir, "marketing_url");

      if (description != null) attrs.description = description;
      if (keywords != null) attrs.keywords = keywords;
      if (promo != null) attrs.promotionalText = promo;
      if (releaseNotes != null) attrs.whatsNew = releaseNotes;
      if (support != null) attrs.supportUrl = support;
      if (marketing != null) attrs.marketingUrl = marketing;

      step(`[${platform} · ${loc.dir}] ${Object.keys(attrs).length} field(s)`);

      const existing = existingByLocale.get(localeCode);

      if (DRY_RUN) {
        info(`(dry-run) would ${existing ? "PATCH" : "CREATE"} appStoreVersionLocalization for ${localeCode}`);
        for (const [k, val] of Object.entries(attrs)) {
          const preview = String(val).replace(/\n/g, " ").slice(0, 80);
          dim(`${k}: ${preview}${String(val).length > 80 ? "…" : ""}`);
        }
      } else if (existing) {
        await asc(`/v1/appStoreVersionLocalizations/${existing.id}`, {
          method: "PATCH",
          body: {
            data: {
              type: "appStoreVersionLocalizations",
              id: existing.id,
              attributes: attrs,
            },
          },
        });
        ok(`Updated ${platform} · ${localeCode}`);
        updated++;
      } else {
        await asc(`/v1/appStoreVersionLocalizations`, {
          method: "POST",
          body: {
            data: {
              type: "appStoreVersionLocalizations",
              attributes: { ...attrs, locale: localeCode },
              relationships: {
                appStoreVersion: { data: { type: "appStoreVersions", id: versionId } },
              },
            },
          },
        });
        ok(`Created ${platform} · ${localeCode}`);
        created++;
      }
    }
  }

  // ---- Push app-level metadata (shared across platforms via appInfo) ------
  for (const loc of allLocales) {
    if (ONLY && !ONLY.has(loc.dir)) continue;
    const localeDir = path.join(METADATA_DIR, loc.dir);
    if (!fs.existsSync(localeDir)) continue;

    const subtitle = readMetadataField(loc.dir, "subtitle");
    const name = readMetadataField(loc.dir, "name");
    const privacy = readMetadataField(loc.dir, "privacy_url");

    if (subtitle != null || name != null || privacy != null) {
      await updateAppInfoLocalization({ appId, loc, subtitle, name, privacyUrl: privacy, dryRun: DRY_RUN });
      nameUpdates++;
    }
  }

  step("Summary");
  info(`Platforms touched: ${versions.length} (${versions.map(v => v.attributes?.platform).join(", ")})`);
  info(`Version locales updated: ${updated}`);
  info(`Version locales created: ${created}`);
  info(`App-level (name/subtitle/privacyUrl) touched: ${nameUpdates}`);
  if (DRY_RUN) warn("Dry-run mode: no changes were actually sent to App Store Connect.");
}

// --- AppInfo localization (name / subtitle / privacy URL) ------------------

const appInfoCache = { appId: null, appInfoId: null, locsByLocale: null };

// App Store Connect removed `filter[appStoreState]` from the appInfos
// endpoint, so we list all recent appInfos and filter client-side by state.
const APPINFO_EDITABLE_STATES = new Set([
  "PREPARE_FOR_SUBMISSION",
  "DEVELOPER_REJECTED",
  "REJECTED",
  "METADATA_REJECTED",
  "WAITING_FOR_REVIEW",
  "IN_REVIEW",
]);

async function getEditableAppInfo(appId) {
  if (appInfoCache.appId === appId && appInfoCache.appInfoId) return appInfoCache;
  const res = await asc(`/v1/apps/${appId}/appInfos?limit=10`);
  const infos = res?.data ?? [];
  // Apple renamed `appStoreState` → `state` on AppInfo. Support both.
  const appInfo = infos.find((info) => {
    const s = info.attributes?.state ?? info.attributes?.appStoreState;
    return s && APPINFO_EDITABLE_STATES.has(s);
  });
  if (!appInfo) {
    const states = infos.map((i) => i.attributes?.state ?? i.attributes?.appStoreState).filter(Boolean);
    fail(`No editable appInfo found — can't push app-level fields (name/subtitle). Current states: ${states.join(", ") || "none"}`);
  }
  const locsRes = await asc(`/v1/appInfos/${appInfo.id}/appInfoLocalizations?limit=200`);
  const locsByLocale = new Map();
  for (const l of locsRes?.data ?? []) locsByLocale.set(l.attributes?.locale, l);
  appInfoCache.appId = appId;
  appInfoCache.appInfoId = appInfo.id;
  appInfoCache.locsByLocale = locsByLocale;
  return appInfoCache;
}

async function updateAppInfoLocalization({ appId, loc, subtitle, name, privacyUrl, dryRun }) {
  const { appInfoId, locsByLocale } = await getEditableAppInfo(appId);
  const localeCode = loc.dir;

  const attrs = {};
  if (name != null) attrs.name = name;
  if (subtitle != null) attrs.subtitle = subtitle;
  if (privacyUrl != null) attrs.privacyPolicyUrl = privacyUrl;
  if (Object.keys(attrs).length === 0) return;

  const existing = locsByLocale.get(localeCode);
  if (dryRun) {
    info(`(dry-run) would ${existing ? "PATCH" : "CREATE"} appInfoLocalization for ${localeCode}: ${Object.keys(attrs).join(", ")}`);
    return;
  }
  if (existing) {
    await asc(`/v1/appInfoLocalizations/${existing.id}`, {
      method: "PATCH",
      body: { data: { type: "appInfoLocalizations", id: existing.id, attributes: attrs } },
    });
    ok(`AppInfo ${localeCode}: ${Object.keys(attrs).join(", ")} updated`);
  } else {
    await asc(`/v1/appInfoLocalizations`, {
      method: "POST",
      body: {
        data: {
          type: "appInfoLocalizations",
          attributes: { ...attrs, locale: localeCode },
          relationships: { appInfo: { data: { type: "appInfos", id: appInfoId } } },
        },
      },
    });
    ok(`AppInfo ${localeCode}: created with ${Object.keys(attrs).join(", ")}`);
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
