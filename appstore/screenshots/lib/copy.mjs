/**
 * copy.mjs — the marketing text a scene draws.
 *
 * It used to live in a `COPY` object inside each scene, which is why only two
 * languages existed: adding a locale meant editing eighteen files. The strings
 * now sit in `copy/<locale>.json`, with en-US as the source of truth and the
 * rest produced by `translate-copy.mjs`.
 *
 * A missing locale falls back to en-US rather than failing: a screenshot in
 * English is a poor screenshot, a missing screenshot is a missing screenshot.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../copy");
export const SOURCE_LOCALE = "en-US";

const cache = new Map();

function read(locale) {
  if (cache.has(locale)) return cache.get(locale);
  const file = path.join(DIR, `${locale}.json`);
  const value = fs.existsSync(file) ? JSON.parse(fs.readFileSync(file, "utf8")) : null;
  cache.set(locale, value);
  return value;
}

/**
 * Strings for one scene, merged over the shared block, with English behind
 * anything the locale is missing.
 *
 * @param {string} scene  key in copy/<locale>.json, e.g. "hero"
 * @param {string} locale e.g. "fr-FR"
 */
export function copyFor(scene, locale) {
  const source = read(SOURCE_LOCALE);
  if (!source) throw new Error(`copy.mjs: copy/${SOURCE_LOCALE}.json is missing`);
  const target = locale === SOURCE_LOCALE ? source : (read(locale) ?? source);

  return {
    ...source.shared, ...(source[scene] ?? {}),
    ...target.shared, ...(target[scene] ?? {}),
  };
}

/** Locales that actually have a copy file — what render.sh iterates over. */
export function availableLocales() {
  if (!fs.existsSync(DIR)) return [SOURCE_LOCALE];
  return fs.readdirSync(DIR)
    .filter((f) => f.endsWith(".json"))
    .map((f) => f.slice(0, -5))
    .sort();
}

/** True for locales whose script runs right-to-left. */
export function isRTL(locale) {
  return /^(ar|he|fa|ur)(-|$)/.test(locale);
}
