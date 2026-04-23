/**
 * deepl.mjs — shared DeepL helpers for the App Store pipeline.
 * Auto-detects the right endpoint based on key suffix (`:fx` = free).
 */

/** Pick the right DeepL endpoint based on the key suffix. */
export function deeplApiBaseForKey(authKey) {
  return String(authKey).endsWith(":fx")
    ? "https://api-free.deepl.com"
    : "https://api.deepl.com";
}

/** Returns the set of supported target language codes reported by DeepL. */
export async function deeplSupportedTargets(apiBase, authKey) {
  const url = `${apiBase.replace(/\/$/, "")}/v2/languages?type=target`;
  const res = await fetch(url, { headers: { "Authorization": `DeepL-Auth-Key ${authKey}` } });
  const json = await res.json().catch(() => null);
  if (!res.ok || !Array.isArray(json)) {
    throw new Error(`DeepL languages error: HTTP ${res.status}`);
  }
  return new Set(json.map((x) => x.language));
}

/**
 * Translate a single piece of text. `preserve_formatting=1` keeps line breaks
 * + punctuation intact.
 */
export async function deeplTranslate({ apiBase, authKey, text, targetLang, sourceLang }) {
  const url = `${apiBase.replace(/\/$/, "")}/v2/translate`;
  const body = new URLSearchParams();
  body.append("text", text);
  body.set("target_lang", targetLang);
  if (sourceLang) body.set("source_lang", sourceLang);
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
  if (!res.ok || !json?.translations?.[0]) {
    throw new Error(`DeepL translate error: HTTP ${res.status} ${await res.text().catch(() => "")}`);
  }
  return json.translations[0].text;
}
