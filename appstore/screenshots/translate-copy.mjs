#!/usr/bin/env node
/**
 * translate-copy.mjs — fill `copy/<locale>.json` from `copy/en-US.json`.
 *
 * The scene scripts used to carry their marketing text inline, which is why only
 * two languages ever existed: a new locale meant editing eighteen files. The
 * strings now live in one JSON per language, and this fills the ones DeepL is
 * allowed to write.
 *
 * It follows the rules the rest of the pipeline already uses:
 *   • brand terms are protected (deepl-protect.mjs → tag_handling=xml)
 *   • the app's own description is sent as DeepL `context`, so a lone word like
 *     "Modules" is translated as an interface label and not as furniture
 *   • locales marked `isHandWritten` in appstore/config.json are never touched
 *   • a per-string hash means only *changed* English is re-translated, so an
 *     edited headline is redone and a hand-fixed translation elsewhere survives
 *
 * Some values are never translated: acronyms, URLs, the brand lockup. They are
 * listed in NEVER_TRANSLATE below, with the reason.
 *
 * Usage:
 *   node translate-copy.mjs                 # every stale/missing locale
 *   node translate-copy.mjs --only=de-DE
 *   node translate-copy.mjs --dry-run
 *   node translate-copy.mjs --force         # ignore hashes, redo everything
 *   node translate-copy.mjs --key=<deepl>   # else $DEEPL_AUTH_KEY / ../.env
 */

import fs from "node:fs";
import path from "node:path";
import crypto from "node:crypto";
import { fileURLToPath } from "node:url";

import { deeplApiBaseForKey, deeplTranslate } from "../lib/deepl.mjs";
import { protect, unprotect, IGNORE_TAGS } from "../../deepl-protect.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const COPY_DIR = path.join(HERE, "copy");
const CONFIG = JSON.parse(fs.readFileSync(path.join(HERE, "../config.json"), "utf8"));
const SIGNATURES = path.join(COPY_DIR, ".copy-signatures.json");
const SOURCE = CONFIG.sourceLocale ?? "en-US";

/**
 * Values that must come out the other side unchanged.
 *
 * `signature` is the company's lockup, in English everywhere by design — the
 * same reasoning that keeps "Radical QR" untranslated. The rest are acronyms,
 * pixel counts, and URLs; DeepL would happily localise a domain name.
 */
const NEVER_TRANSLATE = new Set([
  "signature",        // brand lockup — English in every locale, on purpose
  "signatureBrand",   // domain name
  "appName",          // brand
  "sizes",            // pixel counts
  "formats",          // PNG, SVG, PDF — the same acronyms everywhere
  "kindURL",          // "URL" is "URL"
  "readValue",        // a URL shown inside a mockup
  "captionValue",     // ditto
  "selection",        // ditto
]);

/** Sent to DeepL as `context` so short interface words land in the right sense. */
const KEY_CONTEXT = {
  labelModules: "Label above a row of options that set the corner shape of the small squares making up a QR code.",
  labelEyes: "Label for the three corner markers of a QR code (the finder patterns).",
  labelEyeSize: "Label for the size of a QR code's three corner markers.",
  labelSolid: "A single flat colour, as opposed to a gradient.",
  labelGradient: "A colour gradient, two colours blending. Not a slope.",
  labelBackground: "The background of the generated image.",
  labelLogo: "A logo image placed in the middle of the QR code.",
  labelCaption: "A line of text printed under the QR code in the exported image.",
  labelSize: "Export size in pixels.",
  labelFormat: "Export file format.",
  labelMyStyles: "The user's own saved visual styles.",
  save: "Button that saves the generated QR code to a file.",
  paste: "Button label. Verb: paste the clipboard contents.",
  duplicate: "Button label. Verb: read an existing QR code so the user can recreate it.",
  browse: "Button that opens the system file picker.",
  after: "Short caption under a QR code that has just been recreated with new styling.",
  before: "Short caption under a QR code that was just read from a picture.",
  recent: "Heading over a strip of recently created QR codes.",
  sidebarGenerator: "macOS sidebar item leading to the QR code generator screen.",
  sidebarHistory: "macOS sidebar item leading to the list of past QR codes.",
  sidebarHelp: "macOS sidebar item leading to the help screen.",
  menuTitle: "The macOS 'Services' submenu in a right-click menu. Use the system's own name for it.",
  menuItem: "Menu item that creates a QR code from the current selection.",
};

// --- Arguments -------------------------------------------------------------

const args = Object.fromEntries(process.argv.slice(2).flatMap((a) => {
  if (!a.startsWith("--")) return [];
  const eq = a.indexOf("=");
  return eq === -1 ? [[a.slice(2), true]] : [[a.slice(2, eq), a.slice(eq + 1)]];
}));

const DRY_RUN = Boolean(args["dry-run"]);
const FORCE = Boolean(args.force);
const ONLY = typeof args.only === "string"
  ? new Set(args.only.split(",").map((s) => s.trim()))
  : null;

const COL = { green: "\x1b[32m", yellow: "\x1b[33m", cyan: "\x1b[36m", magenta: "\x1b[35m", dim: "\x1b[2m", reset: "\x1b[0m" };
const step = (m) => console.log(`\n${COL.magenta}> ${m}${COL.reset}`);
const ok = (m) => console.log(`  ${COL.green}+ ${m}${COL.reset}`);
const warn = (m) => console.log(`  ${COL.yellow}! ${m}${COL.reset}`);
const info = (m) => console.log(`  ${COL.cyan}i ${m}${COL.reset}`);
const dim = (m) => console.log(`  ${COL.dim}${m}${COL.reset}`);

function resolveKey() {
  if (typeof args.key === "string") return args.key;
  if (process.env.DEEPL_AUTH_KEY) return process.env.DEEPL_AUTH_KEY;
  // Same fallback as updLocalisation.sh: the sibling .env holds DEEPL_API_KEY.
  for (const candidate of [path.join(HERE, "../../../.env"), path.join(HERE, "../../.env")]) {
    if (!fs.existsSync(candidate)) continue;
    const match = fs.readFileSync(candidate, "utf8").match(/^\s*DEEPL_API_KEY\s*=\s*(.+)\s*$/m);
    if (match) return match[1].trim().replace(/^["']|["']$/g, "");
  }
  return null;
}

// --- Walking the copy tree -------------------------------------------------

const hash = (value) => crypto.createHash("sha1").update(String(value)).digest("hex").slice(0, 12);

/**
 * Translate `source` into `target`, reusing whatever in `existing` still matches
 * the signature recorded for it. Strings and arrays of strings only — the copy
 * files are two levels deep by design.
 */
async function translateSection({ source, existing, signatures, translate, sectionKey }) {
  const out = {};
  let done = 0;
  let reused = 0;

  for (const [key, value] of Object.entries(source)) {
    if (key.startsWith("_")) continue;

    const signatureKey = `${sectionKey}.${key}`;

    if (NEVER_TRANSLATE.has(key)) {
      out[key] = value;
      continue;
    }

    const stamp = hash(JSON.stringify(value));
    const isFresh = !FORCE && signatures[signatureKey] === stamp && existing[key] !== undefined;
    if (isFresh) {
      out[key] = existing[key];
      reused += 1;
      continue;
    }

    if (Array.isArray(value)) {
      out[key] = [];
      for (const line of value) {
        out[key].push(line ? await translate(line, key) : line);
      }
    } else if (typeof value === "string") {
      out[key] = value ? await translate(value, key) : value;
    } else {
      out[key] = value;
    }

    signatures[signatureKey] = stamp;
    done += 1;
  }

  return { out, done, reused };
}

// --- Main ------------------------------------------------------------------

async function main() {
  const sourceFile = path.join(COPY_DIR, `${SOURCE}.json`);
  if (!fs.existsSync(sourceFile)) {
    console.error(`Error: ${sourceFile} is missing.`);
    process.exit(1);
  }
  const sourceCopy = JSON.parse(fs.readFileSync(sourceFile, "utf8"));

  const targets = (CONFIG.targetLocales ?? [])
    .filter((locale) => !ONLY || ONLY.has(locale.dir));

  if (!targets.length) {
    warn("No target locales selected.");
    return;
  }

  const authKey = resolveKey();
  if (!authKey && !DRY_RUN) {
    console.error("Error: no DeepL key. Pass --key=<key>, set DEEPL_AUTH_KEY, or put DEEPL_API_KEY in ../.env");
    process.exit(1);
  }
  const apiBase = authKey ? deeplApiBaseForKey(authKey) : null;

  const allSignatures = fs.existsSync(SIGNATURES)
    ? JSON.parse(fs.readFileSync(SIGNATURES, "utf8"))
    : {};

  const terms = CONFIG.protectedTerms;

  for (const locale of targets) {
    step(`${locale.dir} (DeepL ${locale.deepl})`);

    if (locale.isHandWritten) {
      const file = path.join(COPY_DIR, `${locale.dir}.json`);
      if (fs.existsSync(file)) {
        info(`hand-written — left alone (${locale.note ?? "isHandWritten"})`);
      } else {
        warn(`hand-written but copy/${locale.dir}.json does not exist — scenes will fall back to ${SOURCE}`);
      }
      continue;
    }

    const file = path.join(COPY_DIR, `${locale.dir}.json`);
    const existing = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : {};
    const signatures = allSignatures[locale.dir] ?? (allSignatures[locale.dir] = {});

    const translate = async (text, key) => {
      if (DRY_RUN) return `[${locale.deepl}] ${text}`;
      const context = [CONFIG.appContext, KEY_CONTEXT[key]].filter(Boolean).join(" ");
      const translated = await deeplTranslate({
        apiBase, authKey,
        text: protect(text, terms),
        targetLang: locale.deepl,
        sourceLang: CONFIG.deeplSourceLang,
        tagHandling: "xml",
        ignoreTags: IGNORE_TAGS,
        context,
      });
      return unprotect(translated);
    };

    const result = {};
    let translated = 0;
    let reused = 0;

    for (const [sectionKey, section] of Object.entries(sourceCopy)) {
      if (sectionKey.startsWith("_") || typeof section !== "object") continue;
      const outcome = await translateSection({
        source: section,
        existing: existing[sectionKey] ?? {},
        signatures, translate, sectionKey,
      });
      result[sectionKey] = outcome.out;
      translated += outcome.done;
      reused += outcome.reused;
    }

    if (translated === 0) {
      dim(`up to date (${reused} strings unchanged)`);
      continue;
    }

    if (DRY_RUN) {
      info(`would translate ${translated} string(s), reuse ${reused}`);
      continue;
    }

    fs.writeFileSync(file, `${JSON.stringify(result, null, 2)}\n`);
    ok(`${translated} translated, ${reused} reused → copy/${locale.dir}.json`);
  }

  if (!DRY_RUN) {
    fs.writeFileSync(SIGNATURES, `${JSON.stringify(allSignatures, null, 2)}\n`);
  }

  step("Done");
  if (DRY_RUN) warn("Dry run — nothing written.");
}

main().catch((e) => {
  console.error(e.stack || String(e));
  process.exit(1);
});
