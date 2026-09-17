#!/usr/bin/env node
/**
 * appstore-previews.mjs
 *
 * Téléverse les App Previews de `appstore/previews/out/` vers App Store Connect,
 * dans la version éditable de chaque plateforme — le pendant vidéo de
 * appstore-screenshots.mjs, avec le même protocole en trois temps :
 *   1. POST /v1/appPreviews       → réserve l'asset (uploadOperations)
 *   2. PUT sur chaque opération   → les octets
 *   3. PATCH /v1/appPreviews/{id} → uploaded:true + MD5 (+ image d'affiche)
 * Apple traite ensuite la vidéo ; le script attend COMPLETE un moment puis
 * rend la main (le traitement peut se poursuivre côté Apple).
 *
 * Fichiers → emplacements :
 *   preview-<n>-…-<locale>.mp4      iPhone 6.9″  (IPHONE_67, 886×1920)
 *   mac-preview-<n>-…-<locale>.mp4  Mac          (DESKTOP, 1920×1080)
 * triés par <n> : la vidéo 1 est celle qui passe en autoplay dans la recherche.
 *
 * Usage :
 *   node appstore-previews.mjs --list
 *   node appstore-previews.mjs --dry-run
 *   node appstore-previews.mjs                  # remplace les vidéos existantes
 *   node appstore-previews.mjs --only=fr-FR
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
const OUT_DIR = path.join(SCRIPT_DIR, "appstore/previews/out");
const BUNDLE_ID = args["bundle-id"] || CONFIG.bundleID;
const DRY_RUN = Boolean(args["dry-run"]);
const LIST_ONLY = Boolean(args.list);
const ONLY = typeof args.only === "string" ? new Set(args.only.split(",").map((s) => s.trim())) : null;

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

const asc = createAscClient({
  issuerId: ISSUER_ID, keyId: KEY_ID, keyPath: KEY_PATH, fail,
  retryWritesOnNetworkError: true,
  onRetry: ({ method, pathname, reason, attempt, attempts, delayMs }) =>
    warn(`\n    ${method} ${pathname} → ${reason}, nouvel essai dans ${delayMs / 1000} s (${attempt}/${attempts - 1})`),
});

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

// Image d'affiche (HH:MM:SS:FF à 30 i/s) : le formulaire rempli pour la 1,
// le code stylé avec son logo pour la 2.
const SLOTS = [
  { platform: "IOS", type: "IPHONE_67", match: /^preview-(\d)-/, poster: { 1: "00:00:04:00", 2: "00:00:17:00" } },
  { platform: "MAC_OS", type: "DESKTOP", match: /^mac-preview-(\d)-/, poster: { 1: "00:00:04:15", 2: "00:00:17:00" } },
];

function filesFor(slot, locale) {
  if (!fs.existsSync(OUT_DIR)) return [];
  return fs.readdirSync(OUT_DIR)
    .filter((f) => f.endsWith(`-${locale}.mp4`) && slot.match.test(f))
    .sort((a, b) => Number(a.match(slot.match)[1]) - Number(b.match(slot.match)[1]));
}

async function uploadPreview(setId, filePath, frameTimeCode) {
  const buffer = fs.readFileSync(filePath);
  const fileName = path.basename(filePath);
  const reservation = await asc("/v1/appPreviews", {
    method: "POST",
    body: {
      data: {
        type: "appPreviews",
        attributes: { fileSize: buffer.length, fileName, mimeType: "video/mp4" },
        relationships: { appPreviewSet: { data: { type: "appPreviewSets", id: setId } } },
      },
    },
  });
  const id = reservation.data.id;
  for (const op of reservation.data.attributes.uploadOperations ?? []) {
    const headers = {};
    for (const h of op.requestHeaders ?? []) headers[h.name] = h.value;
    const res = await fetchRetry(op.url, { method: op.method, headers, body: buffer.subarray(op.offset, op.offset + op.length) });
    if (!res.ok) fail(`Envoi de ${fileName} : HTTP ${res.status}`);
  }
  await asc(`/v1/appPreviews/${id}`, {
    method: "PATCH",
    body: {
      data: {
        type: "appPreviews", id,
        attributes: {
          uploaded: true,
          sourceFileChecksum: crypto.createHash("md5").update(buffer).digest("hex"),
          ...(frameTimeCode ? { previewFrameTimeCode: frameTimeCode } : {}),
        },
      },
    },
  });
  // La vidéo est transcodée par Apple : on attend jusqu'à ~3 minutes.
  for (let attempt = 0; attempt < 90; attempt += 1) {
    const res = await asc(`/v1/appPreviews/${id}`);
    const state = res?.data?.attributes?.assetDeliveryState;
    if (state?.state === "COMPLETE") return { id, state: "COMPLETE" };
    if (state?.state === "FAILED") {
      return { id, state: "FAILED", errors: (state.errors ?? []).map((e) => `${e.code}: ${e.description}`).join("; ") };
    }
    await new Promise((r) => setTimeout(r, 2000));
  }
  return { id, state: "PROCESSING" };
}

async function main() {
  step(`Application : ${BUNDLE_ID}`);
  const app = (await asc(`/v1/apps?filter[bundleId]=${encodeURIComponent(BUNDLE_ID)}&limit=1`))?.data?.[0];
  if (!app) fail(`Aucune app pour le bundle id ${BUNDLE_ID}.`);
  ok(`App id : ${app.id}`);

  step("Versions éditables");
  const versions = (await asc(
    `/v1/apps/${app.id}/appStoreVersions?filter[appStoreState]=PREPARE_FOR_SUBMISSION,DEVELOPER_REJECTED,REJECTED,METADATA_REJECTED&limit=20`
  ))?.data ?? [];
  if (!versions.length) { warn("Aucune version éditable."); return; }
  versions.forEach((v) => ok(`${v.attributes?.platform} v${v.attributes?.versionString} (${v.attributes?.appStoreState})`));

  const wanted = [CONFIG.sourceLocale, ...CONFIG.targetLocales.map((l) => l.dir)].filter((l) => !ONLY || ONLY.has(l));
  let uploaded = 0, processing = 0, failed = 0;

  for (const version of versions) {
    const platform = version.attributes?.platform;
    const slots = SLOTS.filter((s) => s.platform === platform);
    if (!slots.length) continue;
    const localizations = new Map(
      ((await asc(`/v1/appStoreVersions/${version.id}/appStoreVersionLocalizations?limit=200`))?.data ?? [])
        .map((l) => [l.attributes?.locale, l.id])
    );

    for (const locale of wanted) {
      const locId = localizations.get(locale);
      if (!locId) { warn(`${platform} / ${locale} : localisation absente sur ASC`); continue; }
      const sets = new Map(
        ((await asc(`/v1/appStoreVersionLocalizations/${locId}/appPreviewSets?limit=50&include=appPreviews`))?.data ?? [])
          .map((s) => [s.attributes?.previewType, s])
      );

      for (const slot of slots) {
        const files = filesFor(slot, locale);
        if (!files.length) { dim(`${platform} / ${locale} / ${slot.type} : aucune vidéo`); continue; }
        if (LIST_ONLY) {
          const count = sets.get(slot.type)?.relationships?.appPreviews?.data?.length ?? 0;
          info(`${platform} / ${locale} / ${slot.type} : ${count} en ligne, ${files.length} en local`);
          continue;
        }
        if (DRY_RUN) {
          info(`(à blanc) ${platform} / ${locale} / ${slot.type} : ${files.join(", ")}`);
          continue;
        }

        let set = sets.get(slot.type);
        if (!set) {
          set = (await asc("/v1/appPreviewSets", {
            method: "POST",
            body: {
              data: {
                type: "appPreviewSets",
                attributes: { previewType: slot.type },
                relationships: { appStoreVersionLocalization: { data: { type: "appStoreVersionLocalizations", id: locId } } },
              },
            },
          })).data;
        }
        for (const old of (await asc(`/v1/appPreviewSets/${set.id}/appPreviews?limit=50`))?.data ?? []) {
          await asc(`/v1/appPreviews/${old.id}`, { method: "DELETE" });
        }

        process.stdout.write(`  ${platform} / ${locale} / ${slot.type} `);
        for (const file of files) {
          const n = Number(file.match(slot.match)[1]);
          const result = await uploadPreview(set.id, path.join(OUT_DIR, file), slot.poster[n]);
          if (result.state === "COMPLETE") { uploaded += 1; process.stdout.write("."); }
          else if (result.state === "PROCESSING") { processing += 1; process.stdout.write("~"); }
          else { failed += 1; process.stdout.write("✗"); warn(`\n    ${file} → ${result.errors}`); }
        }
        console.log(` ${files.length} envoyée(s)`);
      }
    }
  }

  step("Bilan");
  info(`Traitées : ${uploaded}  |  Encore en traitement chez Apple : ${processing}  |  Échecs : ${failed}`);
  if (DRY_RUN || LIST_ONLY) warn("Aucune modification envoyée.");
}

main().catch((e) => fail(e.stack || String(e)));
