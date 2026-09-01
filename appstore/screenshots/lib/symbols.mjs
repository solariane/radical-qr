/**
 * symbols.mjs — the SF Symbols the generator actually uses, redrawn as SVG.
 *
 * rsvg-convert has no access to the SF Symbols font, and the app's icons are
 * never decorative: the rail is *only* icons, so a wrong glyph makes the
 * screenshot say the wrong thing. Each symbol is drawn in a 0…100 box and
 * scaled by `symbol()`, so a caller thinks in points like the SwiftUI code does.
 *
 * These are readable approximations, not Apple's outlines — close enough at the
 * 18pt the rail draws them, and legally ours.
 */

/** Stroke width, in the 0…100 box, for a symbol asked for at `weight`. */
const WEIGHT = { regular: 7, medium: 8, semibold: 9.5, bold: 11 };

const PATHS = {
  // Rail — My styles
  star: (w) => `
    <path d="M50 12 L61 38 L89 41 L68 60 L74 88 L50 74 L26 88 L32 60 L11 41 L39 38 Z"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linejoin="round"/>`,

  "star.fill": () => `
    <path d="M50 10 L62 37 L91 40 L69 60 L75 89 L50 74 L25 89 L31 60 L9 40 L38 37 Z" fill="CURRENT"/>`,

  // Rail — Color
  paintpalette: (w) => `
    <path d="M50 12 C25 12 8 30 8 51 C8 72 25 88 46 88 C55 88 58 83 55 78
             C51 71 55 65 63 65 L74 65 C84 65 92 58 92 47 C92 27 74 12 50 12 Z"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linejoin="round"/>
    <circle cx="28" cy="45" r="6" fill="CURRENT"/>
    <circle cx="44" cy="31" r="6" fill="CURRENT"/>
    <circle cx="64" cy="34" r="6" fill="CURRENT"/>
    <circle cx="76" cy="49" r="6" fill="CURRENT"/>`,

  // Rail — Logo and caption
  photo: (w) => `
    <rect x="7" y="20" width="86" height="60" rx="13" ry="13"
      fill="none" stroke="CURRENT" stroke-width="${w}"/>
    <path d="M12 71 L36 47 L54 65 L68 53 L88 71"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>
    <circle cx="66" cy="37" r="7" fill="CURRENT"/>`,

  "photo.on.rectangle": (w) => `
    <rect x="26" y="14" width="67" height="52" rx="11" ry="11"
      fill="none" stroke="CURRENT" stroke-width="${w}"/>
    <path d="M31 58 L49 40 L62 53 L72 44 L88 59"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M74 78 A11 11 0 0 1 63 89 L18 89 A11 11 0 0 1 7 78 L7 41"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>`,

  // Rail — Export, and the Save button
  "square.and.arrow.down": (w) => `
    <path d="M50 8 L50 62 M32 45 L50 63 L68 45"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M22 40 L16 40 A9 9 0 0 0 7 49 L7 83 A9 9 0 0 0 16 92 L84 92 A9 9 0 0 0 93 83 L93 49 A9 9 0 0 0 84 40 L78 40"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>`,

  "square.and.arrow.up": (w) => `
    <path d="M50 66 L50 12 M32 29 L50 11 L68 29"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M22 40 L16 40 A9 9 0 0 0 7 49 L7 83 A9 9 0 0 0 16 92 L84 92 A9 9 0 0 0 93 83 L93 49 A9 9 0 0 0 84 40 L78 40"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>`,

  "doc.on.doc": (w) => `
    <rect x="28" y="8" width="65" height="60" rx="12" ry="12"
      fill="none" stroke="CURRENT" stroke-width="${w}"/>
    <path d="M72 68 L72 80 A12 12 0 0 1 60 92 L19 92 A12 12 0 0 1 7 80 L7 40 A12 12 0 0 1 19 28 L28 28"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`,

  "doc.on.clipboard": (w) => `
    <rect x="34" y="34" width="59" height="58" rx="12" ry="12"
      fill="none" stroke="CURRENT" stroke-width="${w}"/>
    <path d="M34 62 L20 62 A12 12 0 0 1 8 50 L8 22 A12 12 0 0 1 20 10 L50 10 A12 12 0 0 1 62 22 L62 34"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>
    <rect x="24" y="3" width="22" height="14" rx="6" ry="6" fill="CURRENT"/>`,

  folder: (w) => `
    <path d="M7 32 L7 76 A11 11 0 0 0 18 87 L82 87 A11 11 0 0 0 93 76 L93 41 A11 11 0 0 0 82 30 L50 30 L42 20 A9 9 0 0 0 35 17 L18 17 A11 11 0 0 0 7 28 Z"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linejoin="round"/>
    <path d="M7 34 L93 34" fill="none" stroke="CURRENT" stroke-width="${w}" opacity="0.9"/>`,

  // Duplicate — read an existing code
  "qrcode.viewfinder": (w) => `
    <path d="M8 32 L8 19 A11 11 0 0 1 19 8 L32 8 M68 8 L81 8 A11 11 0 0 1 92 19 L92 32
             M92 68 L92 81 A11 11 0 0 1 81 92 L68 92 M32 92 L19 92 A11 11 0 0 1 8 81 L8 68"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>
    <rect x="26" y="26" width="17" height="17" rx="3.5" ry="3.5" fill="CURRENT"/>
    <rect x="57" y="26" width="17" height="17" rx="3.5" ry="3.5" fill="CURRENT"/>
    <rect x="26" y="57" width="17" height="17" rx="3.5" ry="3.5" fill="CURRENT"/>
    <rect x="57" y="57" width="8" height="8" rx="2" ry="2" fill="CURRENT"/>
    <rect x="68" y="66" width="8" height="8" rx="2" ry="2" fill="CURRENT"/>`,

  camera: (w) => `
    <rect x="6" y="26" width="88" height="58" rx="14" ry="14"
      fill="none" stroke="CURRENT" stroke-width="${w}"/>
    <circle cx="50" cy="55" r="16" fill="none" stroke="CURRENT" stroke-width="${w}"/>
    <path d="M34 26 L39 17 A6 6 0 0 1 44 14 L56 14 A6 6 0 0 1 61 17 L66 26"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linejoin="round"/>`,

  "lock.shield": (w) => `
    <path d="M50 6 C64 15 78 18 90 18 C90 55 78 82 50 94 C22 82 10 55 10 18 C22 18 36 15 50 6 Z"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linejoin="round"/>
    <rect x="34" y="47" width="32" height="26" rx="7" ry="7" fill="CURRENT"/>
    <path d="M40 47 L40 39 A10 10 0 0 1 60 39 L60 47"
      fill="none" stroke="CURRENT" stroke-width="${w * 0.8}"/>`,

  "lock.fill": () => `
    <rect x="20" y="44" width="60" height="48" rx="13" ry="13" fill="CURRENT"/>
    <path d="M32 44 L32 32 A18 18 0 0 1 68 32 L68 44"
      fill="none" stroke="CURRENT" stroke-width="11"/>`,

  questionmark: (w) => `
    <path d="M31 33 A19 19 0 1 1 50 58 L50 66"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>
    <circle cx="50" cy="84" r="6.5" fill="CURRENT"/>`,

  checkmark: (w) => `
    <path d="M13 53 L38 78 L87 22"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`,

  chevron: (w) => `
    <path d="M36 20 L66 50 L36 80"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`,

  link: (w) => `
    <path d="M42 58 A18 18 0 0 1 42 34 L58 18 A18 18 0 0 1 84 44 L74 54"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>
    <path d="M58 42 A18 18 0 0 1 58 66 L42 82 A18 18 0 0 1 16 56 L26 46"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>`,

  // macOS sidebar
  qrcode: () => `
    <rect x="8" y="8" width="26" height="26" rx="3" fill="none" stroke="CURRENT" stroke-width="8"/>
    <rect x="66" y="8" width="26" height="26" rx="3" fill="none" stroke="CURRENT" stroke-width="8"/>
    <rect x="8" y="66" width="26" height="26" rx="3" fill="none" stroke="CURRENT" stroke-width="8"/>
    <rect x="46" y="8" width="9" height="9" fill="CURRENT"/>
    <rect x="46" y="26" width="9" height="9" fill="CURRENT"/>
    <rect x="46" y="46" width="9" height="9" fill="CURRENT"/>
    <rect x="64" y="46" width="9" height="9" fill="CURRENT"/>
    <rect x="83" y="46" width="9" height="9" fill="CURRENT"/>
    <rect x="46" y="64" width="9" height="9" fill="CURRENT"/>
    <rect x="64" y="83" width="9" height="9" fill="CURRENT"/>
    <rect x="83" y="64" width="9" height="9" fill="CURRENT"/>`,

  "clock.arrow.circlepath": (w) => `
    <path d="M50 12 A38 38 0 1 1 15 36" fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>
    <path d="M12 10 L14 37 L40 32" fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>
    <path d="M50 30 L50 52 L66 62" fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round" stroke-linejoin="round"/>`,

  "questionmark.circle": (w) => `
    <circle cx="50" cy="50" r="41" fill="none" stroke="CURRENT" stroke-width="${w}"/>
    <path d="M38 40 A12.5 12.5 0 1 1 50 57 L50 62"
      fill="none" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>
    <circle cx="50" cy="74" r="4.5" fill="CURRENT"/>`,

  gear: (w) => `
    <circle cx="50" cy="50" r="16" fill="none" stroke="CURRENT" stroke-width="${w}"/>
    ${[0, 45, 90, 135, 180, 225, 270, 315].map((a) => {
      const r = (a * Math.PI) / 180;
      const x1 = 50 + Math.cos(r) * 26, y1 = 50 + Math.sin(r) * 26;
      const x2 = 50 + Math.cos(r) * 40, y2 = 50 + Math.sin(r) * 40;
      return `<path d="M${x1} ${y1} L${x2} ${y2}" stroke="CURRENT" stroke-width="${w}" stroke-linecap="round"/>`;
    }).join("")}`,

  sparkles: () => `
    <path d="M34 8 L41 27 L60 34 L41 41 L34 60 L27 41 L8 34 L27 27 Z" fill="CURRENT"/>
    <path d="M74 48 L79 61 L92 66 L79 71 L74 84 L69 71 L56 66 L69 61 Z" fill="CURRENT" opacity="0.75"/>`,
};

/**
 * Draw one symbol centred on (cx, cy), `size` points across.
 * `weight` mirrors SwiftUI's Font.Weight on `.font(.system(size:weight:))`.
 */
export function symbol(name, cx, cy, size, color, weight = "medium") {
  const draw = PATHS[name];
  if (!draw) throw new Error(`symbols.mjs: no glyph for "${name}"`);
  const s = size / 100;
  const body = draw(WEIGHT[weight] ?? WEIGHT.medium).replaceAll("CURRENT", color);
  return `<g transform="translate(${cx - size / 2} ${cy - size / 2}) scale(${s})">${body}</g>`;
}

export function hasSymbol(name) {
  return Object.hasOwn(PATHS, name);
}
