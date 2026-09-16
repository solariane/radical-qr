#!/usr/bin/env node
// Lists every translation in a .xcstrings catalog whose format specifiers
// (%@, %lld, %1$@, %%…) differ from the English source.
//
// Usage: node check-format-specifiers.mjs [path/to/Localizable.xcstrings ...]
// Exit code 1 when anything is wrong, so it can gate a build or a script.
import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { compareSpecifiers, describeSpecifiers } from "./format-specifiers.mjs";

const here = path.dirname(fileURLToPath(import.meta.url));
const defaults = [
  path.join(here, "Radical QR/Resources/Localizable.xcstrings"),
  path.join(here, "Radical QR/Resources/InfoPlist.xcstrings"),
];

/** Every stringUnit under a localization, keyed by its variation path ("plural.one"). */
function units(node, prefix = "") {
  const out = [];
  if (node?.stringUnit) out.push([prefix, node.stringUnit.value ?? ""]);
  for (const [kind, cases] of Object.entries(node?.variations || {})) {
    for (const [name, child] of Object.entries(cases)) {
      out.push(...units(child, prefix ? `${prefix}.${kind}.${name}` : `${kind}.${name}`));
    }
  }
  return out;
}

async function check(file) {
  let catalog;
  try {
    catalog = JSON.parse(await fs.readFile(file, "utf8"));
  } catch (e) {
    if (e.code === "ENOENT") return 0;
    throw e;
  }
  const sourceLang = catalog.sourceLanguage || "en";
  let count = 0;

  for (const key of Object.keys(catalog.strings || {}).sort()) {
    const entry = catalog.strings[key];
    const locs = entry.localizations || {};
    // No source localization: the key itself is the English text.
    const sourceUnits = new Map(units(locs[sourceLang]));
    const fallback = sourceUnits.get("") ?? sourceUnits.get("plural.other") ?? key;

    for (const lang of Object.keys(locs).sort()) {
      if (lang === sourceLang) continue;
      for (const [variation, value] of units(locs[lang])) {
        // Plural forms are matched to the same category when English has it;
        // Arabic's "few"/"many" fall back to English "other".
        const source = sourceUnits.get(variation) ?? fallback;
        const problems = compareSpecifiers(source, value);
        if (!problems.length) continue;
        count++;
        const where = variation ? `${key} [${lang} ${variation}]` : `${key} [${lang}]`;
        console.log(where);
        console.log(`    en: ${JSON.stringify(source)}  → ${describeSpecifiers(source)}`);
        console.log(`    ${lang}: ${JSON.stringify(value)}  → ${describeSpecifiers(value)}`);
        for (const p of problems) console.log(`    - ${p}`);
      }
    }
  }
  console.error(`${path.basename(file)}: ${count} mismatch(es)`);
  return count;
}

const files = process.argv.length > 2 ? process.argv.slice(2).map(f => path.resolve(f)) : defaults;
let total = 0;
for (const f of files) total += await check(f);
process.exit(total ? 1 : 0);
