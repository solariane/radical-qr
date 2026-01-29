#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { DOMParser, XMLSerializer } from "@xmldom/xmldom";
import xpath from "xpath";

function fail(msg, code = 1) { console.error("Error:", msg); process.exit(code); }
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
async function isDir(p){ try { return (await fs.stat(p)).isDirectory(); } catch { return false; } }

function normalizeBcp47(tag) {
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
  const norm = normalizeBcp47(bcp47);
  if (!norm) return [];
  const parts = norm.split("-");
  const lang = parts[0].toUpperCase();
  const region = parts.find(p => p.length === 2 || p.length === 3)?.toUpperCase();
  const c = [];
  if (region) c.push(`${lang}-${region}`);
  c.push(lang);
  if (lang === "EN") c.unshift("EN-US", "EN-GB");
  if (lang === "PT" && !region) c.unshift("PT-PT", "PT-BR");
  if (lang === "ZH") c.unshift("ZH");
  return [...new Set(c)];
}

async function findXclocs(inputPath) {
  if (inputPath.endsWith(".xcloc") && await isDir(inputPath)) return [inputPath];
  if (!await isDir(inputPath)) fail(`Input must be a directory or a .xcloc folder: ${inputPath}`);
  const children = await fs.readdir(inputPath, { withFileTypes: true });
  return children.filter(d => d.isDirectory() && d.name.endsWith(".xcloc"))
    .map(d => path.join(inputPath, d.name));
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
async function copyDir(src, dst) {
  await fs.mkdir(dst, { recursive: true });
  const entries = await fs.readdir(src, { withFileTypes: true });
  for (const e of entries) {
    const from = path.join(src, e.name);
    const to = path.join(dst, e.name);
    if (e.isDirectory()) await copyDir(from, to);
    else if (e.isFile()) await fs.copyFile(from, to);
  }
}
function pLimit(concurrency) {
  let active = 0; const q = [];
  const next = () => {
    if (active >= concurrency || q.length === 0) return;
    active++;
    const { fn, resolve, reject } = q.shift();
    fn().then(resolve, reject).finally(() => { active--; next(); });
  };
  return (fn) => new Promise((resolve, reject) => { q.push({ fn, resolve, reject }); next(); });
}

async function deeplSupportedTargets(apiBase, authKey) {
  const url = `${apiBase.replace(/\/$/, "")}/v2/languages?type=target`;
  const res = await fetch(url, { headers: { "Authorization": `DeepL-Auth-Key ${authKey}` }});
  const json = await res.json().catch(() => null);
  if (!res.ok || !Array.isArray(json)) fail(`DeepL languages error: HTTP ${res.status}`);
  return new Set(json.map(x => x.language));
}

async function deeplTranslateBatch(apiBase, authKey, texts, targetLang, sourceLang) {
  // Use tag_handling=xml by wrapping each source in <t>...</t> (well-formed)
  const url = `${apiBase.replace(/\/$/, "")}/v2/translate`;
  const body = new URLSearchParams();
  for (const t of texts) body.append("text", `<t>${t}</t>`);
  body.set("target_lang", targetLang);
  if (sourceLang) body.set("source_lang", sourceLang);
  body.set("tag_handling", "xml");
  body.set("preserve_formatting", "1");

  const res = await fetch(url, {
    method: "POST",
    headers: {
      "Authorization": `DeepL-Auth-Key ${authKey}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: body.toString(),
  });

  const json = await res.json().catch(() => null);
  if (!res.ok || !json?.translations) {
    fail(`DeepL translate error: HTTP ${res.status} ${await res.text().catch(()=> "")}`);
  }
  // unwrap <t>...</t>
  return json.translations.map(x => {
    const s = x.text ?? "";
    return s.replace(/^<t>/, "").replace(/<\/t>$/, "");
  });
}

function detectTargetLangFromXliffDoc(doc, xclocNameFallback) {
  const select = xpath.useNamespaces({
    x: "urn:oasis:names:tc:xliff:document:1.2",
  });

  // Try <file target-language="...">
  const fileNode = select("//x:file", doc)[0];
  const attr = fileNode?.getAttribute?.("target-language");
  if (attr) return attr;

  // Try <xliff target-language="..."> (rare)
  const xliffNode = select("//x:xliff", doc)[0];
  const attr2 = xliffNode?.getAttribute?.("target-language");
  if (attr2) return attr2;

  return xclocNameFallback;
}

function innerXml(node) {
  const ser = new XMLSerializer();
  let s = "";
  for (let c = node.firstChild; c; c = c.nextSibling) s += ser.serializeToString(c);
  return s;
}
function replaceChildrenFromXml(doc, parent, xmlFragment) {
  while (parent.firstChild) parent.removeChild(parent.firstChild);
  if (!xmlFragment) return;

  // Parse fragment as XML inside a wrapper
  const wrapped = `<w>${xmlFragment}</w>`;
  const fragDoc = new DOMParser().parseFromString(wrapped, "application/xml");
  const w = fragDoc.documentElement;
  const ser = new XMLSerializer();

  for (let c = w.firstChild; c; c = c.nextSibling) {
    // importNode not available in xmldom reliably; reparse node string into current doc
    const asStr = ser.serializeToString(c);
    if (asStr.startsWith("<") && !asStr.startsWith("<?")) {
      const nDoc = new DOMParser().parseFromString(asStr, "application/xml");
      const n = nDoc.documentElement;
      parent.appendChild(doc.importNode ? doc.importNode(n, true) : n);
    } else {
      parent.appendChild(doc.createTextNode(c.nodeValue ?? asStr));
    }
  }
}

async function processXliffFile(filePath, apiBase, authKey, targetLang, sourceLang) {
  const xml = await fs.readFile(filePath, "utf8");
  const doc = new DOMParser().parseFromString(xml, "application/xml");

  const select = xpath.useNamespaces({
    x: "urn:oasis:names:tc:xliff:document:1.2",
  });

  const transUnits = select("//x:trans-unit", doc);
  if (!transUnits.length) return { filePath, translated: 0, skipped: 0 };

  const sources = [];
  const unitsNeeding = [];

  for (const tu of transUnits) {
    const src = select("x:source", tu)[0];
    if (!src) continue;

    const tgt = select("x:target", tu)[0];
    // If already has a target with content, skip (you can change behavior if you want overwrite)
    if (tgt && tgt.textContent && tgt.textContent.trim().length) continue;

    const srcInner = innerXml(src).trim();
    if (!srcInner) continue;

    sources.push(srcInner);
    unitsNeeding.push(tu);
  }

  if (!sources.length) return { filePath, translated: 0, skipped: transUnits.length };

  // DeepL batches: chunk for safety
  const chunkSize = 40;
  let translatedCount = 0;

  for (let i = 0; i < sources.length; i += chunkSize) {
    const chunk = sources.slice(i, i + chunkSize);
    const outs = await deeplTranslateBatch(apiBase, authKey, chunk, targetLang, sourceLang);

    for (let j = 0; j < outs.length; j++) {
      const tu = unitsNeeding[i + j];
      const tgtExisting = select("x:target", tu)[0];

      let tgt = tgtExisting;
      if (!tgt) {
        tgt = doc.createElementNS("urn:oasis:names:tc:xliff:document:1.2", "target");
        tu.appendChild(tgt);
      }

      tgt.setAttribute("state", "translated");
      replaceChildrenFromXml(doc, tgt, outs[j]);
      translatedCount++;
    }
  }

  const outXml = new XMLSerializer().serializeToString(doc);
  await fs.writeFile(filePath, outXml, "utf8");
  return { filePath, translated: translatedCount, skipped: transUnits.length - translatedCount };
}

async function main() {
  const args = parseArgs(process.argv);
  const input = args._[0];
  if (!input) fail("Missing input path (folder containing .xcloc, or a .xcloc folder).");

  const authKey = process.env.DEEPL_AUTH_KEY;
  if (!authKey) fail("Missing env var DEEPL_AUTH_KEY.");

  const apiBase = args["api-base"] || "https://api.deepl.com";
  const concurrency = Number(args.concurrency || 6);
  const inplace = Boolean(args.inplace);
  const outRoot = args.out ? path.resolve(args.out) : path.resolve(input, "translated");
  const sourceLang = args.source ? String(args.source).toUpperCase() : null;

  const xclocs = await findXclocs(input);
  if (!xclocs.length) fail(`No .xcloc found in: ${input}`);

  const supportedTargets = await deeplSupportedTargets(apiBase, authKey);
  const limit = pLimit(concurrency);

  if (!inplace) await fs.mkdir(outRoot, { recursive: true });

  const jobs = [];

  for (const xcloc of xclocs) {
    const baseName = path.basename(xcloc);
    const outXcloc = inplace ? xcloc : path.join(outRoot, baseName);

    if (!inplace) {
      await fs.rm(outXcloc, { recursive: true, force: true });
      await copyDir(xcloc, outXcloc);
    }

    const xliffs = await findXliffs(outXcloc);
    if (!xliffs.length) {
      console.error(`- ${baseName}: no .xliff/.xlf found (skip)`);
      continue;
    }

    // Detect target language from first xliff's target-language, fallback to xcloc name
    const xclocLangFallback = path.basename(outXcloc, ".xcloc");
    const sample = await fs.readFile(xliffs[0], "utf8");
    const doc = new DOMParser().parseFromString(sample, "application/xml");
    const detected = detectTargetLangFromXliffDoc(doc, xclocLangFallback);

    const candidates = buildDeeplCandidates(detected);
    const targetLang = candidates.find(c => supportedTargets.has(c));
    if (!targetLang) {
      fail(`Cannot map target language for ${baseName}. Detected="${detected}". Tried: ${candidates.join(", ") || "(none)"}`);
    }

    console.error(`- ${baseName}: ${xliffs.length} file(s) -> DeepL target_lang=${targetLang}`);

    for (const f of xliffs) {
      jobs.push(limit(async () => {
        const r = await processXliffFile(f, apiBase, authKey, targetLang, sourceLang);
        console.error(`  OK ${baseName}:${path.basename(f)} translated=${r.translated} skipped=${r.skipped}`);
      }));
    }
  }

  if (!jobs.length) {
    console.error("Nothing to do.");
    return;
  }

  await Promise.all(jobs);
  console.error(`Done. Output: ${inplace ? "(in-place)" : outRoot}`);
}

main().catch(e => fail(e?.stack || String(e)));