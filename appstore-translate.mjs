#!/usr/bin/env node
/**
 * appstore-translate.mjs
 *
 * Translates the App Store metadata files in `appstore/metadata/<locale>/*.txt`
 * from the source locale (en-US) to every target locale declared in
 * `appstore/config.json`, using DeepL.
 *
 * Mirrors the behaviour of `deepl-xcloc-translate.mjs` (hash-based
 * invalidation) but works on plain `.txt` files instead of XLIFF.
 *
 * Usage:
 *   DEEPL_AUTH_KEY=... node appstore-translate.mjs [--source=EN]
 *                                                   [--api-base=https://api-free.deepl.com]
 *                                                   [--force]
 *                                                   [--only=<locale>[,<locale>...]]
 *
 * - Per-field sha256 signature tracked in `.appstore-signatures.json`
 * - Fields listed under `translatableFields` go through DeepL
 * - Fields listed under `copyAsIsFields` are copied with locale-aware
 *   path substitution for URLs
 * - Character limits enforced per field (warn + flag, never truncate mid-word)
 * - Locales flagged `isHandWritten: true` are never auto-translated
 */

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";
import { protect, unprotect, IGNORE_TAGS, DEFAULT_PROTECTED_TERMS } from "./deepl-protect.mjs";
import { translate } from "../translate.mjs";

// Fields where Claude beats DeepL (short / branded / keyword / marketing copy).
// Everything else (notably the long `description`) stays on DeepL.
const CLAUDE_FIELDS = new Set(["name", "subtitle", "keywords", "promotional_text", "release_notes"]);

// --- CLI parsing -----------------------------------------------------------

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
const METADATA_DIR = path.join(SCRIPT_DIR, "appstore", "metadata");
const CONFIG_PATH = path.join(SCRIPT_DIR, "appstore", "config.json");
const SIGS_PATH = path.join(SCRIPT_DIR, "appstore", ".appstore-signatures.json");

const SOURCE_LANG_DEEPL = (args.source || "EN").toUpperCase();
const API_BASE = args["api-base"] || "https://api.deepl.com";
const FORCE = Boolean(args.force);
const ONLY = typeof args.only === "string" ? new Set(args.only.split(",").map(s => s.trim())) : null;

const AUTH_KEY = process.env.DEEPL_AUTH_KEY;
if (!AUTH_KEY) {
  console.error("Error: DEEPL_AUTH_KEY environment variable not set.");
  process.exit(1);
}

// --- Helpers ---------------------------------------------------------------

const COL = { red: "\x1b[31m", green: "\x1b[32m", yellow: "\x1b[33m", cyan: "\x1b[36m", magenta: "\x1b[35m", reset: "\x1b[0m", dim: "\x1b[2m" };
const step = (m) => console.log(`\n${COL.magenta}> ${m}${COL.reset}`);
const ok = (m) => console.log(`  ${COL.green}+ ${m}${COL.reset}`);
const warn = (m) => console.log(`  ${COL.yellow}! ${m}${COL.reset}`);
const info = (m) => console.log(`  ${COL.cyan}i ${m}${COL.reset}`);
const dim = (m) => console.log(`  ${COL.dim}${m}${COL.reset}`);
const fail = (m) => { console.error(`${COL.red}Error: ${m}${COL.reset}`); process.exit(1); };

const sha256 = (s) => crypto.createHash("sha256").update(s, "utf8").digest("hex");

function loadJSON(p, fallback) {
  try { return JSON.parse(fs.readFileSync(p, "utf8")); }
  catch (e) {
    if (e.code === "ENOENT") return fallback;
    throw e;
  }
}

function saveJSON(p, obj) {
  fs.writeFileSync(p, JSON.stringify(obj, null, 2) + "\n", "utf8");
}

// --- DeepL -----------------------------------------------------------------

async function deeplSupportedTargets() {
  const url = `${API_BASE.replace(/\/$/, "")}/v2/languages?type=target`;
  const res = await fetch(url, { headers: { "Authorization": `DeepL-Auth-Key ${AUTH_KEY}` } });
  const json = await res.json().catch(() => null);
  if (!res.ok || !Array.isArray(json)) fail(`DeepL languages error: HTTP ${res.status}`);
  return new Set(json.map((x) => x.language));
}

async function deeplTranslate(text, targetLang, terms = DEFAULT_PROTECTED_TERMS) {
  const url = `${API_BASE.replace(/\/$/, "")}/v2/translate`;
  const body = new URLSearchParams();
  // protect() XML-escapes the text and wraps brand terms in <x>...</x>; with
  // tag_handling=xml + ignore_tags=x DeepL leaves those spans untouched.
  body.append("text", protect(text, terms));
  body.set("target_lang", targetLang);
  body.set("source_lang", SOURCE_LANG_DEEPL);
  body.set("tag_handling", "xml");
  body.set("ignore_tags", IGNORE_TAGS);
  body.set("preserve_formatting", "1");

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `DeepL-Auth-Key ${AUTH_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: body.toString(),
  });
  const json = await res.json().catch(() => null);
  if (!res.ok || !json?.translations?.[0]) {
    fail(`DeepL translate error: HTTP ${res.status} ${await res.text().catch(() => "")}`);
  }
  return unprotect(json.translations[0].text);
}

// --- URL locale path mapping -----------------------------------------------

/**
 * Mirror the `websiteLang` logic used by the iOS/macOS app (PaywallView.swift)
 * so URLs in metadata line up with the hosted site structure.
 */
function websiteLangFor(deeplCode) {
  const c = String(deeplCode).toLowerCase();
  if (c === "fr") return "fr";
  if (c === "de") return "de";
  if (c === "es") return "es";
  if (c === "it") return "it";
  if (c.startsWith("pt")) return "pt-br";
  if (c === "ja") return "ja";
  if (c === "ar") return "ar";
  if (c === "hi") return "hi";
  if (c.startsWith("zh")) return "zh-hans";
  return "en";
}

function localizeUrl(srcUrl, sourceLangPath, targetLangPath) {
  // Replace /<sourceLang>/ segment with /<targetLang>/ if present.
  const re = new RegExp(`/${sourceLangPath}(/|$)`);
  return srcUrl.replace(re, `/${targetLangPath}$1`);
}

// --- Main ------------------------------------------------------------------

async function main() {
  const config = loadJSON(CONFIG_PATH);
  if (!config) fail(`Missing ${CONFIG_PATH}`);

  const srcDir = path.join(METADATA_DIR, config.sourceLocale);
  if (!fs.existsSync(srcDir)) fail(`Source locale dir not found: ${srcDir}`);

  const sigs = loadJSON(SIGS_PATH, {}); // { "<locale>": { "<field>": "<sha>" } }

  // Lazily load DeepL's supported target list on first use — skips the network
  // call entirely when every target in `--only` is hand-written.
  let _supported = null;
  const supported = async () => {
    if (_supported) return _supported;
    step("Checking DeepL supported targets...");
    _supported = await deeplSupportedTargets();
    info(`DeepL reports ${_supported.size} target languages available.`);
    return _supported;
  };

  const sourceLangPath = websiteLangFor(SOURCE_LANG_DEEPL);

  let translations = 0, skips = 0, copies = 0, warnings = 0;

  for (const loc of config.targetLocales) {
    if (ONLY && !ONLY.has(loc.dir)) continue;

    step(`[${loc.dir}] ${loc.isHandWritten ? "(hand-written, no auto-translate)" : `DeepL: ${loc.deepl}`}`);

    const targetDir = path.join(METADATA_DIR, loc.dir);
    if (!fs.existsSync(targetDir)) {
      warn(`Missing target dir, creating: ${targetDir}`);
      fs.mkdirSync(targetDir, { recursive: true });
    }

    sigs[loc.dir] ??= {};

    // --- translatable fields
    for (const field of config.translatableFields) {
      const srcFile = path.join(srcDir, `${field}.txt`);
      if (!fs.existsSync(srcFile)) {
        dim(`Skip (no source): ${field}`);
        continue;
      }
      const srcText = fs.readFileSync(srcFile, "utf8").replace(/\s+$/, "");
      const srcHash = sha256(srcText);
      const targetFile = path.join(targetDir, `${field}.txt`);

      const haveTarget = fs.existsSync(targetFile);
      const sigMatches = sigs[loc.dir][field] === srcHash;

      if (loc.isHandWritten) {
        if (!haveTarget) {
          warn(`${field}: missing target file (hand-written locale, skipping)`);
          continue;
        }
        // Still track the signature so future runs know nothing needs to change.
        sigs[loc.dir][field] = srcHash;
        skips++;
        continue;
      }

      if (!FORCE && haveTarget && sigMatches) {
        dim(`Skip (unchanged): ${field}`);
        skips++;
        continue;
      }

      const engine = CLAUDE_FIELDS.has(field) ? "claude" : "deepl";

      // Only DeepL needs the language to be in its supported-target set.
      if (engine === "deepl") {
        const targets = await supported();
        if (!targets.has(loc.deepl)) {
          warn(`${field}: DeepL target "${loc.deepl}" not supported, skipping`);
          continue;
        }
      }

      process.stdout.write(`  ${COL.cyan}→${COL.reset} Translating ${field} (${engine})... `);
      const { out } = await translate([srcText], {
        engine,
        field,
        source: SOURCE_LANG_DEEPL,
        target: loc.deepl,
        limit: config.fieldLimits?.[field],
        protect: config.protectedTerms,
        context: config.appContext,
      });
      const translated = out[0];
      process.stdout.write(`${COL.green}done${COL.reset}\n`);

      // Validate character limits.
      const limit = config.fieldLimits?.[field];
      if (limit && translated.length > limit) {
        warn(`${field}: translation length ${translated.length} > ${limit} char limit — REVIEW MANUALLY`);
        warnings++;
      }

      fs.writeFileSync(targetFile, translated + "\n", "utf8");
      sigs[loc.dir][field] = srcHash;
      ok(`${field} (${translated.length} chars)`);
      translations++;
    }

    // --- copy-as-is fields (URLs, etc.) with path substitution
    const targetLangPath = websiteLangFor(loc.deepl);
    for (const field of config.copyAsIsFields) {
      const srcFile = path.join(srcDir, `${field}.txt`);
      if (!fs.existsSync(srcFile)) continue;
      const srcText = fs.readFileSync(srcFile, "utf8").replace(/\s+$/, "");
      const localized = localizeUrl(srcText, sourceLangPath, targetLangPath);

      const targetFile = path.join(targetDir, `${field}.txt`);
      const current = fs.existsSync(targetFile) ? fs.readFileSync(targetFile, "utf8").replace(/\s+$/, "") : null;
      if (current === localized) continue;

      fs.writeFileSync(targetFile, localized + "\n", "utf8");
      ok(`${field}: ${localized}`);
      copies++;
    }
  }

  saveJSON(SIGS_PATH, sigs);

  step("Summary");
  info(`Translated: ${translations}`);
  info(`Skipped (unchanged or hand-written): ${skips}`);
  info(`URLs copied/localized: ${copies}`);
  if (warnings > 0) warn(`Char-limit warnings: ${warnings} — review the flagged fields`);
  ok(`Signatures saved to ${path.relative(SCRIPT_DIR, SIGS_PATH)}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
