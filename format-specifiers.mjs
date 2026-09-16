// Printf-style format specifiers in localized strings, shared by
// check-format-specifiers.mjs (audits the .xcstrings catalog) and
// deepl-xcloc-translate.mjs (rejects a DeepL output that damaged them).
//
// DeepL treats "%lld" as text: in Arabic "%lld%%" came back as "%لـ %د%", and
// "%1$@" as "%1$$@". Neither is caught by Xcode — String(format:) just prints
// garbage, or crashes when a %@ ends up reading an integer.
//
// Two strings agree when every argument keeps the same conversion (a positional
// "%2$@ … %1$@" may reorder "%@ … %@"), the number of literal "%%" is the same,
// and no stray "%" is left that is not a valid specifier.

// %[n$][flags][width][.precision][length]conversion, plus Xcode's %#@name@.
const SPEC = /%(?:%|#@[A-Za-z0-9_]+@|(?:(\d+)\$)?[-+ #0']*(?:\d+|\*)?(?:\.(?:\d+|\*))?(hh|h|ll|l|q|L|z|t|j)?([@dDiuUxXoOfFeEgGcCsSpaA]))/g;

/**
 * Tokens of `text`, in order: { raw, kind: "arg"|"percent"|"subst"|"stray", index?, conv? }.
 * `conv` is the specifier without its position ("lld", "@", ".1f"), which is
 * what has to survive translation.
 */
export function parseSpecifiers(text) {
  const tokens = [];
  let next = 1;
  let last = 0;
  const strays = (from, to) => {
    for (let i = text.indexOf("%", from); i !== -1 && i < to; i = text.indexOf("%", i + 1)) {
      tokens.push({ raw: "%", kind: "stray", at: i });
    }
  };
  for (const m of text.matchAll(SPEC)) {
    strays(last, m.index);
    last = m.index + m[0].length;
    const raw = m[0];
    if (raw === "%%") { tokens.push({ raw, kind: "percent" }); continue; }
    if (raw.startsWith("%#@")) { tokens.push({ raw, kind: "subst" }); continue; }
    const index = m[1] ? Number(m[1]) : next++;
    const conv = raw.slice(1).replace(/^\d+\$/, "");
    tokens.push({ raw, kind: "arg", index, conv });
  }
  strays(last, text.length);
  return tokens;
}

function signature(text) {
  const tokens = parseSpecifiers(text);
  const args = new Map();
  let percent = 0;
  const substs = [];
  const strays = [];
  for (const t of tokens) {
    if (t.kind === "arg") args.set(t.index, [...(args.get(t.index) || []), t.conv]);
    else if (t.kind === "percent") percent++;
    else if (t.kind === "subst") substs.push(t.raw);
    else strays.push(t.at);
  }
  return { tokens, args, percent, substs: substs.sort(), strays };
}

/**
 * Differences between the specifiers of `source` and `translation`, as
 * human-readable strings. Empty array when they agree.
 */
export function compareSpecifiers(source, translation) {
  const s = signature(source);
  const t = signature(translation);
  const problems = [];

  const indices = [...new Set([...s.args.keys(), ...t.args.keys()])].sort((a, b) => a - b);
  for (const i of indices) {
    const want = (s.args.get(i) || []).join(",");
    const got = (t.args.get(i) || []).join(",");
    if (want !== got) {
      problems.push(`argument ${i}: expected ${want ? "%" + want : "nothing"}, found ${got ? "%" + got : "nothing"}`);
    }
  }
  if (s.percent !== t.percent) {
    problems.push(`"%%": expected ${s.percent}, found ${t.percent}`);
  }
  if (s.substs.join() !== t.substs.join()) {
    problems.push(`substitutions: expected ${s.substs.join(" ") || "none"}, found ${t.substs.join(" ") || "none"}`);
  }
  if (t.strays.length > s.strays.length) {
    problems.push(`${t.strays.length - s.strays.length} stray "%" that is not a valid specifier`);
  }
  return problems;
}

/** The specifiers of `text`, for display: "%1$@ %2$@ %%". */
export function describeSpecifiers(text) {
  return parseSpecifiers(text).map(t => t.raw).join(" ") || "(none)";
}

/**
 * Wrap each specifier of an already XML-escaped string in <x>…</x>, so DeepL
 * (ignore_tags=x) copies it verbatim. unprotect() in deepl-protect.mjs strips
 * the markers again.
 */
export function protectSpecifiers(xmlText) {
  return xmlText.replace(SPEC, m => `<x>${m}</x>`);
}
