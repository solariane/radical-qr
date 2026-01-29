#!/usr/bin/env node
/**
 * DeepL XCLoc (.xcloc) translator (XLIFF inside)
 *
 * Usage:
 *   DEEPL_AUTH_KEY="xxx" node deepl-xcloc-translate.mjs /path/to/exports --concurrency=4
 *
 * Options:
 *   --api-base=https://api.deepl.com        (or https://api-free.deepl.com)
 *   --concurrency=4                        (default 3)
 *   --out=/path/to/outputDir               (default: <input>/translated)
 *   --inplace                              overwrite originals (no copy)
 *   --source=EN                            optional DeepL source_lang
 *
 * Notes:
 *  - target_lang is auto-detected from XLIFF target-language attribute or .xcloc name
 *  - translates all .xliff/.xlf found in each .xcloc package
 */

import fs from "node:fs/promises";
import { createReadStream } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

function fail(msg, code = 1) {
  console.error(`Error: ${msg}`);
  process.exit(code);
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

async function exists(p) {
  try { await fs.access(p); return true; } catch { return false; }
}

async function isDir(p) {
  try { return (await fs.stat(p)).isDirectory(); } catch { return false; }
}

async function mkdirp(p) {
  await fs.mkdir(p, { recursive: true });
}

async function copyDir(src, dst) {
  await mkdirp(dst);
  const entries = await fs.readdir(src, { withFileTypes: true });
  for (const e of entries) {
    const from = path.join(src, e.name);
    const to = path.join(dst, e.name);
    if (e.isDirectory()) await copyDir(from, to);
    else if (e.isFile()) await fs.copyFile(from, to);
  }
}

async function findXclocs(inputPath) {
  if (inputPath.endsWith(".xcloc") && await isDir(inputPath)) return [inputPath];
  if (!await isDir(inputPath)) fail(`Input must be a directory or a .xcloc folder: ${inputPath}`);

  const children = await fs.readdir(inputPath, { withFileTypes: true });
  const xclocs = children
    .filter(d => d.isDirectory() && d.name.endsWith(".xcloc"))
    .map(d => path.join(inputPath, d.name));

  // If not directly inside, do a shallow recursive scan (2 levels) for robustness
  if (xclocs.length) return xclocs;

  const nested = [];
  for (const d of children.filter(d => d.isDirectory())) {
    const sub = path.join(inputPath, d.name);
    const subChildren = await fs.readdir(sub, { withFileTypes: true }).catch(() => []);
    for (const sd of subChildren) {
      if (sd.isDirectory() && sd.name.endsWith(".xcloc")) nested.push(path.join(sub, sd.name));
    }
  }
  return nested;
}

async function findXliffs(root) {
  const out = [];
  async function walk(dir) {
    const entries = await fs.readdir(dir, { withFileTypes: true });
    for (const e of entries) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) await walk(p);
      else if (e.isFile()) {
        const ext = path.extname(e.name).toLowerCase();
        if (ext === ".xliff" || ext === ".xlf") out.push(p);
      }
    }
  }
  await walk(root);
  out.sort();
  return out;
}

function extractTargetLanguageFromXliff(xmlText) {
  // Look for xliff target-language="fr" (case-insensitive)
  const m = xmlText.match(/target-language\s*=\s*["']([^"']+)["']/i);
  if (m?.[1]) return m[1].trim();
  return null;
}

function extractLangFromXclocName(xclocPath) {
  const base = path.basename(xclocPath, ".xcloc"); // e.g. fr, fr-FR, de, pt-BR
  return base || null;
}

function normalizeBcp47(tag) {
  // Normalize separators + casing: fr-fr -> fr-FR, pt_br -> pt-BR, zh-hant -> zh-Hant
  const t = tag.replace(/_/g, "-").trim();
  const parts = t.split("-").filter(Boolean);
  if (!parts.length) return null;

  const lang = parts[0].toLowerCase();
  const rest = parts.slice(1).map(p => {
    if (p.length === 2 || p.length === 3) return p.toUpperCase();        // region
    if (p.length === 4) return p[0].toUpperCase() + p.slice(1).toLowerCase(); // script
    return p;
  });
  return [lang, ...rest].join("-");
}

function buildDeeplCandidates(bcp47) {
  // DeepL uses uppercase language codes, with hyphen variants (e.g., PT-BR, EN-GB)
  const norm = normalizeBcp47(bcp47);
  if (!norm) return [];

  const parts = norm.split("-");
  const lang = parts[0].toUpperCase();
  const region = parts.find(p => p.length === 2 || p.length === 3)?.toUpperCase();

  const candidates = [];

  // 1) If we have lang-region, try that (e.g., pt-BR -> PT-BR)
  if (region) candidates.push(`${lang}-${region}`);

  // 2) Try plain lang (e.g., fr -> FR)
  candidates.push(lang);

  // 3) English special: if xliff says "en", DeepL targets are usually EN-US/EN-GB
  if (lang === "EN") {
    candidates.unshift("EN-US", "EN-GB"); // prefer EN-US then EN-GB by default
  }

  // 4) Portuguese generic sometimes should be PT-PT if only "pt" given
  if (lang === "PT" && !region) {
    candidates.unshift("PT-PT", "PT-BR");
  }

  // 5) Chinese: if tag contains Hans/Hant, try ZH (DeepL commonly uses ZH)
  if (lang === "ZH") {
    candidates.unshift("ZH");
  }

  // Dedup preserving order
  return [...new Set(candidates)];
}

async function fetchJson(url, opts = {}) {
  const res = await fetch(url, opts);
  const text = await res.text();
  let json;
  try { json = JSON.parse(text); } catch { json = null; }
  if (!res.ok) {
    const msg = (json && (json.message || json.error)) ? (json.message || json.error) : text.slice(0, 500);
    fail(`HTTP ${res.status} ${res.statusText} from ${url}: ${msg}`);
  }
  if (!json) fail(`Non-JSON response from ${url}: ${text.slice(0, 500)}`);
  return json;
}

async function deeplGetSupportedTargetLangs(apiBase, authKey) {
  const url = `${apiBase.replace(/\/$/, "")}/v2/languages?type=target`;
  const json = await fetchJson(url, {
    headers: { "Authorization": `DeepL-Auth-Key ${authKey}` }
  });
  // returns array items: { language: "FR", name: "...", supports_formality: ... }
  return new Set(json.map(x => x.language));
}

async function deeplDocumentTranslate(apiBase, authKey, filePath, targetLang, sourceLang) {
  const base = apiBase.replace(/\/$/, "");
  const uploadUrl = `${base}/v2/document`;

  // Use FormData upload
  const buf = await fs.readFile(filePath);
  const blob = new Blob([buf], { type: "application/octet-stream" });

  const fd = new FormData();
  fd.append("file", blob, path.basename(filePath));
  fd.append("target_lang", targetLang);
  if (sourceLang) fd.append("source_lang", sourceLang);

  const upload = await fetchJson(uploadUrl, {
    method: "POST",
    headers: { "Authorization": `DeepL-Auth-Key ${authKey}` },
    body: fd
  });

  const document_id = upload.document_id;
  const document_key = upload.document_key;
  if (!document_id || !document_key) fail(`DeepL upload missing document_id/document_key for ${filePath}`);

  // Poll status
  const statusUrl = `${base}/v2/document/${document_id}`;
  const formBody = new URLSearchParams({ document_key }).toString();

  let sleepMs = 900;
  while (true) {
    const st = await fetchJson(statusUrl, {
      method: "POST",
      headers: {
        "Authorization": `DeepL-Auth-Key ${authKey}`,
        "Content-Type": "application/x-www-form-urlencoded"
      },
      body: formBody
    });

    if (st.status === "done") break;
    if (st.status === "error") fail(`DeepL document error for ${filePath}: ${st.error_message || "unknown"}`);

    const sr = Number.isFinite(st.seconds_remaining) ? st.seconds_remaining : null;
    if (sr !== null && sr > 0) sleepMs = Math.min(5000, Math.max(800, Math.round((sr * 500))));
    else sleepMs = Math.min(5000, sleepMs + 300);

    await new Promise(r => setTimeout(r, sleepMs));
  }

  // Download result
  const dlUrl = `${base}/v2/document/${document_id}/result`;
  const res = await fetch(dlUrl, {
    method: "POST",
    headers: {
      "Authorization": `DeepL-Auth-Key ${authKey}`,
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: formBody
  });
  if (!res.ok) {
    const t = await res.text();
    fail(`Download failed for ${filePath}: HTTP ${res.status} ${res.statusText}: ${t.slice(0, 500)}`);
  }
  const outBuf = Buffer.from(await res.arrayBuffer());

  // Very light sanity check (avoid overwriting with HTML error page etc.)
  const head = outBuf.slice(0, 200).toString("utf8");
  if (!head.includes("<?xml") && !head.toLowerCase().includes("<xliff")) {
    fail(`Downloaded content doesn't look like XLIFF/XML for ${filePath}. Refusing to overwrite.`);
  }

  return outBuf;
}

function pLimit(concurrency) {
  let active = 0;
  const queue = [];
  const next = () => {
    if (active >= concurrency || queue.length === 0) return;
    active++;
    const { fn, resolve, reject } = queue.shift();
    fn().then(resolve, reject).finally(() => {
      active--;
      next();
    });
  };
  return (fn) => new Promise((resolve, reject) => {
    queue.push({ fn, resolve, reject });
    next();
  });
}

async function main() {
  const args = parseArgs(process.argv);
  const input = args._[0];
  if (!input) fail("Missing input path (directory containing .xcloc, or a .xcloc folder).");

  const authKey = process.env.DEEPL_AUTH_KEY;
  if (!authKey) fail("Missing env var DEEPL_AUTH_KEY.");

  const apiBase = args["api-base"] || "https://api.deepl.com";
  const concurrency = Number(args.concurrency || 3);
  const inplace = Boolean(args.inplace);
  const sourceLang = args.source ? String(args.source).toUpperCase() : null;

  const xclocs = await findXclocs(input);
  if (!xclocs.length) fail(`No .xcloc folders found in: ${input}`);

  const outRoot = args.out ? path.resolve(args.out) : path.resolve(input, "translated");
  if (!inplace) await mkdirp(outRoot);

  console.error(`Found ${xclocs.length} .xcloc package(s).`);
  console.error(`API: ${apiBase} | Concurrency: ${concurrency} | Inplace: ${inplace ? "yes" : "no"}`);

  const supportedTargets = await deeplGetSupportedTargetLangs(apiBase, authKey);

  // Prepare work list
  const tasks = [];
  for (const xcloc of xclocs) {
    const baseName = path.basename(xcloc);
    const outXcloc = inplace ? xcloc : path.join(outRoot, baseName);

    if (!inplace) {
      // overwrite output package if already exists
      if (await exists(outXcloc)) await fs.rm(outXcloc, { recursive: true, force: true });
      await copyDir(xcloc, outXcloc);
    }

    const xliffs = await findXliffs(outXcloc);
    if (!xliffs.length) {
      console.error(`- ${baseName}: no .xliff/.xlf found (skipped)`);
      continue;
    }

    // Determine target language: try from first xliff (target-language), fallback xcloc name
    let detected = null;
    try {
      const sample = await fs.readFile(xliffs[0], "utf8");
      detected = extractTargetLanguageFromXliff(sample);
    } catch {}
    if (!detected) detected = extractLangFromXclocName(outXcloc);

    const candidates = detected ? buildDeeplCandidates(detected) : [];
    const targetLang = candidates.find(c => supportedTargets.has(c)) || null;
    if (!targetLang) {
      fail(`Cannot map target language for ${baseName}. Detected="${detected}". Tried: ${candidates.join(", ") || "(none)"}.
Tip: rename the .xcloc to a DeepL code (e.g. fr.xcloc, pt-BR.xcloc), or ensure XLIFF has target-language.`);
    }

    console.error(`- ${baseName}: ${xliffs.length} file(s), target-language="${detected}" -> DeepL target_lang="${targetLang}"`);

    for (const f of xliffs) {
      tasks.push({ xcloc: baseName, file: f, targetLang });
    }
  }

  if (!tasks.length) {
    console.error("Nothing to do.");
    return;
  }

  const limit = pLimit(concurrency);
  let done = 0;

  await Promise.all(tasks.map(t => limit(async () => {
    const rel = `${t.xcloc}:${path.basename(t.file)}`;
    console.error(`  translating ${rel} ...`);
    const outBuf = await deeplDocumentTranslate(apiBase, authKey, t.file, t.targetLang, sourceLang);
    const tmp = `${t.file}.tmp`;
    await fs.writeFile(tmp, outBuf);
    await fs.rename(tmp, t.file);
    done++;
    console.error(`  OK ${rel} (${done}/${tasks.length})`);
  })));

  console.error(`Done. Output: ${inplace ? "(in-place)" : outRoot}`);
}

main().catch(e => fail(e?.stack || String(e)));