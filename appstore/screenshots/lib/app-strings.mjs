/**
 * app-strings.mjs — the app's own UI strings, read from its string catalogs
 * (Localizable.xcstrings, and ServicesMenu.xcstrings for the Mac's right-click item).
 *
 * A screenshot that says « Début » where the app says « Début » is the app; one
 * where DeepL said « Commencer » is another app. Labels that exist in the app
 * are therefore never put in copy/<locale>.json: a scene asks for them here, by
 * the same key the Swift code uses, in the store locale it is drawing.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const RESOURCES = path.resolve(path.dirname(fileURLToPath(import.meta.url)),
  "../../../Radical QR/Resources");

/** App Store locale → catalog language. */
const LANGUAGE = {
  "en-US": "en", "fr-FR": "fr", "de-DE": "de", "es-ES": "es", "it": "it",
  "pt-BR": "pt-BR", "ja": "ja", "ar-SA": "ar", "hi": "hi", "zh-Hans": "zh-Hans",
};

const tables = new Map();

/**
 * The app's string for `key` in the store `locale`, falling back to English.
 * Throws for a key the app does not have — a typo must not ship a blank label.
 */
export function appString(key, locale, table = "Localizable") {
  if (!tables.has(table)) {
    tables.set(table, JSON.parse(fs.readFileSync(path.join(RESOURCES, `${table}.xcstrings`), "utf8")).strings);
  }
  const entry = tables.get(table)[key];
  if (!entry) throw new Error(`app-strings.mjs: no "${key}" in ${table}.xcstrings`);
  const language = LANGUAGE[locale] ?? "en";
  const unit = entry.localizations?.[language]?.stringUnit ?? entry.localizations?.en?.stringUnit;
  if (!unit?.value) throw new Error(`app-strings.mjs: "${key}" has no ${language} or en value`);
  return unit.value;
}

/** The catalog language for a store locale, for Intl date formatting. */
export function intlLocale(locale) {
  return LANGUAGE[locale] ?? "en";
}
