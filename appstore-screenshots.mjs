#!/usr/bin/env node
/**
 * appstore-screenshots.mjs
 *
 * Téléverse les captures de `appstore/screenshots/out/` vers App Store Connect,
 * pour chaque langue et chaque plateforme, en visant la version éditable en
 * cours. `appstore-push.mjs` ne gère que les métadonnées texte.
 *
 * Protocole d'envoi d'un asset (trois temps) :
 *   1. POST /v1/appScreenshots        → réserve l'asset, renvoie des
 *                                        `uploadOperations` (PUT découpés)
 *   2. PUT sur chaque opération        → les octets du fichier
 *   3. PATCH /v1/appScreenshots/{id}   → uploaded:true + somme MD5
 * puis on attend que `assetDeliveryState` passe à COMPLETE.
 *
 * Identifiants : mêmes variables que appstore-push.mjs
 *   ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH
 *
 * Repris de cleanUpPhoneNumbers : même protocole, même config. Les seules
 * différences propres à Radical QR sont la liste des types d'affichage (l'app
 * est aussi sur Mac) et le filtre de fichiers, qui accepte le suffixe de locale
 * en fin de nom tel que render.sh l'écrit.
 *
 * Usage :
 *   node appstore-screenshots.mjs --list          # ce qui existe déjà sur ASC
 *   node appstore-screenshots.mjs --dry-run
 *   node appstore-screenshots.mjs                 # envoie tout
 *   node appstore-screenshots.mjs --only=fr-FR,de-DE
 *   node appstore-screenshots.mjs --keep          # ajoute sans supprimer l'existant
 */

import fs from "node:fs";
import path from "node:path";
import os from "node:os";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { createAscClient } from "./appstore/lib/asc.mjs";

const args = Object.fromEntries(
  process.argv.slice(2).flatMap((a) => {
    if (!a.startsWith("--")) return [];
    const eq = a.indexOf("=");
    return eq === -1 ? [[a.slice(2), true]] : [[a.slice(2, eq), a.slice(eq + 1)]];
  })
);

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const CONFIG = JSON.parse(fs.readFileSync(path.join(SCRIPT_DIR, "appstore/config.json"), "utf8"));
const OUT_DIR = path.join(SCRIPT_DIR, "appstore/screenshots/out");

const BUNDLE_ID = args["bundle-id"] || CONFIG.bundleID;
const DRY_RUN = Boolean(args["dry-run"]);
const LIST_ONLY = Boolean(args.list);
const ONLY = typeof args.only === "string" ? new Set(args.only.split(",").map((s) => s.trim())) : null;
// Par défaut on remplace le jeu complet ; --keep ajoute à côté de l'existant.
const KEEP = Boolean(args.keep);

const ISSUER_ID = process.env.ASC_ISSUER_ID;
const KEY_ID = process.env.ASC_KEY_ID;
let KEY_PATH = process.env.ASC_KEY_PATH;
if (KEY_PATH?.startsWith("~/")) KEY_PATH = path.join(os.homedir(), KEY_PATH.slice(2));

if (!ISSUER_ID || !KEY_ID || !KEY_PATH || !fs.existsSync(KEY_PATH)) {
  console.error("Error: identifiants App Store Connect manquants (ASC_ISSUER_ID, ASC_KEY_ID, ASC_KEY_PATH).");
  process.exit(1);
}

const COL = { red: "\x1b[31m", green: "\x1b[32m", yellow: "\x1b[33m", cyan: "\x1b[36m", magenta: "\x1b[35m", reset: "\x1b[0m", dim: "\x1b[2m" };
const step = (m) => console.log(`\n${COL.magenta}> ${m}${COL.reset}`);
const ok = (m) => console.log(`  ${COL.green}+ ${m}${COL.reset}`);
const warn = (m) => console.log(`  ${COL.yellow}! ${m}${COL.reset}`);
const info = (m) => console.log(`  ${COL.cyan}i ${m}${COL.reset}`);
const dim = (m) => console.log(`  ${COL.dim}${m}${COL.reset}`);
const fail = (m) => { console.error(`${COL.red}Error: ${m}${COL.reset}`); process.exit(1); };

// --- Client ASC -------------------------------------------------------------
//
// Le jeton est renouvelé en cours de route (un envoi complet dépasse les
// 20 minutes qu'Apple accorde à un JWT) et les GET sont repris sur HTTP 5xx.

const asc = createAscClient({
  issuerId: ISSUER_ID,
  keyId: KEY_ID,
  keyPath: KEY_PATH,
  fail,
  // Déjà le cas avant : les coupures réseau isolées sont fréquentes sur 260 envois.
  retryWritesOnNetworkError: true,
  onRetry: ({ method, pathname, reason, attempt, attempts, delayMs }) => {
    if (reason === "HTTP 401") warn(`\n    ${method} ${pathname} → HTTP 401, jeton renouvelé, nouvel essai`);
    else warn(`\n    ${method} ${pathname} → ${reason}, nouvel essai dans ${delayMs / 1000} s (${attempt}/${attempts - 1})`);
  },
});

/**
 * fetch avec reprise, pour les PUT d'octets hors API : coupures réseau isolées
 * et HTTP 5xx. Renvoyer le même morceau au même offset ne change rien s'il
 * était déjà arrivé. La dernière réponse est rendue telle quelle.
 */
async function fetchRetry(url, options, attempts = 4) {
  for (let i = 1; ; i += 1) {
    let reason;
    try {
      const res = await fetch(url, options);
      if (res.status < 500 || i >= attempts) return res;
      await res.body?.cancel();
      reason = `HTTP ${res.status}`;
    } catch (e) {
      if (i >= attempts) throw e;
      reason = e.cause?.code || e.message;
    }
    const delayMs = 1000 * 2 ** i;
    warn(`\n    ${options.method} ${new URL(url).host} → ${reason}, nouvel essai dans ${delayMs / 1000} s (${i}/${attempts - 1})`);
    await new Promise((r) => setTimeout(r, delayMs));
  }
}

// --- Correspondance fichiers → types d'affichage --------------------------
//
// Les suffixes viennent de render.sh. Les tailles sont celles qu'Apple attend
// pour chaque type ; une capture à la mauvaise taille est refusée.

const DISPLAY_TYPES = [
  { platform: "IOS",    type: "APP_IPHONE_67", match: /-iphone-6\.9-/, size: "1290×2796" },
  { platform: "IOS",    type: "APP_IPHONE_65", match: /-iphone-6\.5-/, size: "1284×2778" },
  { platform: "IOS",    type: "APP_IPAD_PRO_3GEN_129", match: /-ipad-/, size: "2064×2752" },
  { platform: "MAC_OS", type: "APP_DESKTOP",   match: /-mac-/,        size: "2880×1800" },
];

function filesFor(displayType, locale) {
  if (!fs.existsSync(OUT_DIR)) return [];
  return fs
    .readdirSync(OUT_DIR)
    .filter((f) => f.endsWith(`-${locale}.png`) && displayType.match.test(f))
    .sort();
}

// --- Envoi d'un fichier ----------------------------------------------------

async function uploadScreenshot(setId, filePath) {
  const buffer = fs.readFileSync(filePath);
  const fileName = path.basename(filePath);

  const reservation = await asc("/v1/appScreenshots", {
    method: "POST",
    body: {
      data: {
        type: "appScreenshots",
        attributes: { fileSize: buffer.length, fileName },
        relationships: { appScreenshotSet: { data: { type: "appScreenshotSets", id: setId } } },
      },
    },
  });

  const id = reservation.data.id;
  const operations = reservation.data.attributes.uploadOperations ?? [];

  for (const op of operations) {
    const headers = {};
    for (const h of op.requestHeaders ?? []) headers[h.name] = h.value;
    const res = await fetchRetry(op.url, {
      method: op.method,
      headers,
      body: buffer.subarray(op.offset, op.offset + op.length),
    });
    if (!res.ok) fail(`Envoi de ${fileName} : HTTP ${res.status} sur ${op.url}`);
  }

  await asc(`/v1/appScreenshots/${id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appScreenshots",
        id,
        attributes: {
          uploaded: true,
          sourceFileChecksum: crypto.createHash("md5").update(buffer).digest("hex"),
        },
      },
    },
  });

  // Apple valide l'image de son côté : on attend le verdict.
  for (let attempt = 0; attempt < 60; attempt += 1) {
    const res = await asc(`/v1/appScreenshots/${id}`);
    const state = res?.data?.attributes?.assetDeliveryState;
    if (state?.state === "COMPLETE") return { id, state: "COMPLETE" };
    if (state?.state === "FAILED") {
      const errors = (state.errors ?? []).map((e) => `${e.code}: ${e.description}`).join("; ");
      return { id, state: "FAILED", errors };
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  return { id, state: "TIMEOUT" };
}

// --- Programme -------------------------------------------------------------

async function main() {
  step(`Application : ${BUNDLE_ID}`);
  const appRes = await asc(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&limit=1`);
  const app = appRes?.data?.[0];
  if (!app) fail(`Aucune app pour le bundle id ${BUNDLE_ID}.`);
  ok(`App id : ${app.id}`);

  step("Versions éditables");
  const versionsRes = await asc(
    `/v1/apps/${app.id}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED,WAITING_FOR_REVIEW&limit=20`
  );
  const versions = versionsRes?.data ?? [];
  if (!versions.length) {
    warn("Aucune version éditable. Créez-en une dans App Store Connect.");
    process.exit(0);
  }
  for (const v of versions) {
    ok(`${v.attributes?.platform} v${v.attributes?.versionString} (${v.attributes?.appStoreState})`);
  }

  const wanted = [CONFIG.sourceLocale, ...CONFIG.targetLocales.map((l) => l.dir)]
    .filter((l) => !ONLY || ONLY.has(l));

  let uploaded = 0, skipped = 0, failed = 0;

  for (const version of versions) {
    const platform = version.attributes?.platform;
    const types = DISPLAY_TYPES.filter((d) => d.platform === platform);
    if (!types.length) continue;

    const locsRes = await asc(
      `/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`
    );
    const localizations = new Map(
      (locsRes?.data ?? []).map((l) => [l.attributes?.locale, l.id])
    );

    for (const locale of wanted) {
      const locId = localizations.get(locale);
      if (!locId) {
        warn(`${platform} / ${locale} : localisation absente sur ASC, ignorée`);
        continue;
      }

      const setsRes = await asc(
        `/v1/appStoreVersionLocalizations/${locId}/appScreenshotSets?limit=50&include=appScreenshots`
      );
      const setsByType = new Map(
        (setsRes?.data ?? []).map((s) => [s.attributes?.screenshotDisplayType, s])
      );

      for (const displayType of types) {
        const files = filesFor(displayType, locale);
        if (!files.length) {
          dim(`${platform} / ${locale} / ${displayType.type} : aucun fichier`);
          continue;
        }

        if (LIST_ONLY) {
          const existing = setsByType.get(displayType.type);
          const count = existing?.relationships?.appScreenshots?.data?.length ?? 0;
          info(`${platform} / ${locale} / ${displayType.type} : ${count} en ligne, ${files.length} en local`);
          continue;
        }

        if (DRY_RUN) {
          info(`(à blanc) ${platform} / ${locale} / ${displayType.type} : ${files.length} fichier(s)`);
          files.forEach((f) => dim(`  ${f}`));
          continue;
        }

        // Le jeu existe-t-il déjà ? Sinon on le crée.
        let set = setsByType.get(displayType.type);
        if (!set) {
          const createRes = await asc("/v1/appScreenshotSets", {
            method: "POST",
            body: {
              data: {
                type: "appScreenshotSets",
                attributes: { screenshotDisplayType: displayType.type },
                relationships: {
                  appStoreVersionLocalization: {
                    data: { type: "appStoreVersionLocalizations", id: locId },
                  },
                },
              },
            },
          });
          set = createRes.data;
        }

        // On remplace : sinon les anciennes captures restent à côté des neuves.
        if (!KEEP) {
          const existingRes = await asc(`/v1/appScreenshotSets/${set.id}/appScreenshots?limit=50`);
          for (const shot of existingRes?.data ?? []) {
            await asc(`/v1/appScreenshots/${shot.id}`, { method: "DELETE" });
          }
        }

        if (files.length > 10) {
          warn(`${platform} / ${locale} / ${displayType.type} : ${files.length} fichiers, App Store Connect n'en accepte que 10 — les suivants seront refusés`);
        }

        process.stdout.write(`  ${platform} / ${locale} / ${displayType.type} `);
        for (const file of files) {
          const result = await uploadScreenshot(set.id, path.join(OUT_DIR, file));
          if (result.state === "COMPLETE") { uploaded += 1; process.stdout.write("."); }
          else { failed += 1; process.stdout.write("✗"); warn(`\n    ${file} → ${result.state} ${result.errors ?? ""}`); }
        }
        console.log(` ${files.length} envoyée(s)`);
      }
    }
  }

  step("Bilan");
  info(`Envoyées : ${uploaded}  |  Échecs : ${failed}  |  Ignorées : ${skipped}`);
  if (DRY_RUN || LIST_ONLY) warn("Aucune modification envoyée.");
}

main().catch((e) => fail(e.stack || String(e)));
