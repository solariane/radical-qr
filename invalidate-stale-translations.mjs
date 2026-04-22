#!/usr/bin/env node
/**
 * invalidate-stale-translations.mjs
 *
 * Reads all .xliff files inside .xcloc folders, computes an MD5 hash of each
 * <source> text, and compares it against stored signatures in a JSON file.
 *
 * - New entries (no stored signature): left as-is (empty target → DeepL will translate)
 * - Changed entries (hash mismatch): target is CLEARED so DeepL re-translates
 * - Unchanged entries: left untouched
 *
 * After processing, the signatures file is updated with current hashes.
 *
 * Usage:
 *   node invalidate-stale-translations.mjs <localizations-dir> [--sigs=.translation-signatures.json]
 */

import fs from "node:fs/promises";
import path from "node:path";
import crypto from "node:crypto";
import { DOMParser, XMLSerializer } from "@xmldom/xmldom";
import xpath from "xpath";

function md5(str) {
  return crypto.createHash("md5").update(str, "utf8").digest("hex");
}

function parseArgs(argv) {
  const args = { _: [] };
  for (const a of argv.slice(2)) {
    if (!a.startsWith("--")) args._.push(a);
    else {
      const eq = a.indexOf("=");
      if (eq === -1) args[a.slice(2)] = true;
      else args[a.slice(2, eq)] = a.slice(eq + 1);
    }
  }
  return args;
}

async function isDir(p) {
  try { return (await fs.stat(p)).isDirectory(); } catch { return false; }
}

async function findXclocs(inputPath) {
  if (inputPath.endsWith(".xcloc") && await isDir(inputPath)) return [inputPath];
  if (!await isDir(inputPath)) { console.error(`Not a directory: ${inputPath}`); process.exit(1); }
  const children = await fs.readdir(inputPath, { withFileTypes: true });
  return children
    .filter(d => d.isDirectory() && d.name.endsWith(".xcloc"))
    .map(d => path.join(inputPath, d.name));
}

async function findXliffs(root) {
  const out = [];
  async function walk(dir) {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    for (const e of entries) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) await walk(p);
      else if (e.isFile() && /\.xliff?$/i.test(path.extname(e.name))) out.push(p);
    }
  }
  await walk(root);
  return out.sort();
}

function innerXml(node) {
  let result = "";
  for (let i = 0; i < node.childNodes.length; i++) {
    result += new XMLSerializer().serializeToString(node.childNodes[i]);
  }
  return result;
}

async function main() {
  const args = parseArgs(process.argv);
  const input = args._[0];
  if (!input) {
    console.error("Usage: node invalidate-stale-translations.mjs <localizations-dir> [--sigs=<file>]");
    process.exit(1);
  }

  const sigsPath = path.resolve(args.sigs || ".translation-signatures.json");

  // Load existing signatures
  let signatures = {};
  try {
    const raw = await fs.readFile(sigsPath, "utf8");
    signatures = JSON.parse(raw);
  } catch {
    // First run — no signatures file yet
  }

  const xclocs = await findXclocs(input);
  if (!xclocs.length) {
    console.error(`No .xcloc found in: ${input}`);
    process.exit(1);
  }

  // Collect current source hashes from all XLIFFs (source is the same across
  // all languages, but we process all to be safe)
  const currentHashes = {};  // key → md5(source)
  let totalCleared = 0;
  let totalNew = 0;
  let totalUnchanged = 0;

  const select = xpath.useNamespaces({ x: "urn:oasis:names:tc:xliff:document:1.2" });

  for (const xcloc of xclocs) {
    const lang = path.basename(xcloc, ".xcloc");
    // Skip the base/source language (en) — no translations to manage
    if (lang === "en") continue;

    const xliffs = await findXliffs(xcloc);

    for (const xliffPath of xliffs) {
      const xml = await fs.readFile(xliffPath, "utf8");
      const doc = new DOMParser().parseFromString(xml, "application/xml");
      const transUnits = select("//x:trans-unit", doc);
      let modified = false;

      for (const tu of transUnits) {
        const id = tu.getAttribute("id") || "";
        const src = select("x:source", tu)[0];
        if (!src) continue;

        const srcText = innerXml(src).trim();
        if (!srcText) continue;

        const hash = md5(srcText);
        const key = id || srcText; // Use id as key, fallback to source text

        currentHashes[key] = hash;

        const tgt = select("x:target", tu)[0];
        const hasTranslation = tgt && tgt.textContent && tgt.textContent.trim().length > 0;

        if (!hasTranslation) {
          // No existing translation — will be picked up by DeepL
          totalNew++;
          continue;
        }

        const storedHash = signatures[key];

        if (!storedHash) {
          // First time seeing this key with a translation — store hash, keep translation
          totalUnchanged++;
          continue;
        }

        if (storedHash === hash) {
          // Source unchanged — keep translation
          totalUnchanged++;
          continue;
        }

        // Source changed — clear the target so DeepL re-translates
        while (tgt.firstChild) tgt.removeChild(tgt.firstChild);
        modified = true;
        totalCleared++;
        console.log(`  [${lang}] Cleared stale: ${key.substring(0, 60)}${key.length > 60 ? "…" : ""}`);
      }

      if (modified) {
        const output = new XMLSerializer().serializeToString(doc);
        await fs.writeFile(xliffPath, output, "utf8");
      }
    }
  }

  // Save updated signatures
  const mergedSigs = { ...signatures, ...currentHashes };
  // Remove signatures for keys that no longer exist in source
  const finalSigs = {};
  for (const [k, v] of Object.entries(mergedSigs)) {
    if (currentHashes[k]) finalSigs[k] = v;
  }
  await fs.writeFile(sigsPath, JSON.stringify(finalSigs, null, 2) + "\n", "utf8");

  console.log(`\nSignature check complete:`);
  console.log(`  ${totalCleared} stale translations cleared (will be re-translated)`);
  console.log(`  ${totalNew} new entries (no translation yet)`);
  console.log(`  ${totalUnchanged} unchanged (kept as-is)`);
  console.log(`  Signatures saved to ${sigsPath}`);
}

main().catch(e => { console.error(e); process.exit(1); });
