// Shared brand/term protection for the DeepL translation scripts
// (deepl-xcloc-translate.mjs and appstore-translate.mjs).
//
// DeepL is asked to translate with tag_handling=xml and ignore_tags=x, so any
// span wrapped in <x>...</x> is left verbatim. We wrap brand/product names
// before sending and strip the markers afterwards. This keeps names like
// "Radical QR" or "Phone Numbers Cleaner" identical across every locale instead
// of being phonetically transliterated (e.g. "QR radical", "電話番号クリーナー").
//
// Keep this list in sync with appstore/config.json -> "protectedTerms"
// (that file's list, when present, takes precedence for the App Store script).

export const DEFAULT_PROTECTED_TERMS = [
  "RadicalSolution.com",
  "Radical Solution",
  "RadicalSolution",
  "Radical QR",
  "RadicalQRShare",
  "Phone Numbers Cleaner",
];

export const IGNORE_TAGS = "x";

function escapeXml(s) {
  return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

function unescapeXml(s) {
  return s
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&amp;/g, "&");
}

function escapeRegExp(s) {
  return s.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

/**
 * XML-escape `text`, then wrap each protected term in <x>...</x>.
 * Terms are matched longest-first (so "RadicalSolution.com" beats
 * "RadicalSolution") in a single global pass — the replacement text is not
 * re-scanned, so there is no double-wrapping.
 */
export function protect(text, terms = DEFAULT_PROTECTED_TERMS) {
  const escaped = escapeXml(text);
  const list = [...terms].filter(Boolean).sort((a, b) => b.length - a.length);
  if (list.length === 0) return escaped;
  const re = new RegExp(list.map(escapeRegExp).join("|"), "g");
  return escaped.replace(re, (m) => `<x>${m}</x>`);
}

/** Remove the <x> markers added by protect() and undo XML escaping. */
export function unprotect(text) {
  return unescapeXml(text.replace(/<\/?x>/g, ""));
}
