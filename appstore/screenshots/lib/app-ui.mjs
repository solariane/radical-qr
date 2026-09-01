/**
 * app-ui.mjs — the Radical QR 2.0 interface, redrawn in SVG.
 *
 * The screenshots are hand-drawn rather than captured, so the only thing keeping
 * them honest is this file: every component here mirrors a real SwiftUI view,
 * with the same numbers.
 *
 *   familyRail        → CustomizationRail.familyRail
 *   settingTile       → SettingTile
 *   moduleShapeGlyph… → ShapeGlyphs (7-unit eye, 1-unit ring, 3-unit pupil, even-odd)
 *   launchCard        → LaunchCard
 *   previewCard       → GeneratorView.previewCard
 *   actionRow         → GeneratorView.actionRow
 *
 * Everything is expressed in **app points**, exactly like the Swift source, and
 * `appScreen()` scales the finished screen into a device frame. That way a
 * change in GeneratorMetrics can be mirrored here by copying numbers, not by
 * re-tuning a drawing.
 */

import { symbol } from "./symbols.mjs";

// MARK: - Palette (from Assets.xcassets and the views' literal colors)

export const INK = {
  /// QRGlyph.ink — every glyph sits on a light tile.
  glyph: "#241F31",
  /// QRGlyph.hairline
  hairline: "#C2BED2",
  /// CustomizationRail.activeInk — icon on an active (white) rail button.
  railActive: "#5B45A8",
  /// The Save button's label.
  save: "#4B3A86",
  /// AccentColor.colorset
  accent: "#667EEA",
  /// LaunchCard's resting drop-target mark.
  markIdle: "#C9C2E6",
  gradientStart: "#667EEA",
  gradientEnd: "#764BA2",
  label: "#1C1C1E",
  secondary: "#6C6C70",
};

export const FONT = `-apple-system, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif`;

// MARK: - GeneratorMetrics

/**
 * The four `GeneratorMetrics` presets, copied value for value.
 *
 * `contentWidth`, `previewColumn` and `layout` come from the same struct: a wide
 * canvas caps the column and centres it, and a wide *short* one moves the
 * settings beside the code instead of under it.
 */

/** GeneratorMetrics.regular — a notched iPhone. */
export const METRICS = {
  preview: 186, tile: 48, swatch: 44,
  tokenWidth: 72, tokenHeight: 48,
  tileGap: 10, labelGap: 5, rowGap: 10, sectionGap: 11,
  panelPadding: 12, cardPadding: 14,
  railHeight: 46, actionHeight: 54, headerHeight: 30,
  contentWidth: Infinity, previewColumn: 0, layout: "column",
};

/** GeneratorMetrics.compact — iPhone SE and 8, or a window squeezed that short. */
export const METRICS_COMPACT = {
  preview: 140, tile: 44, swatch: 40,
  tokenWidth: 64, tokenHeight: 42,
  tileGap: 8, labelGap: 3, rowGap: 7, sectionGap: 8,
  panelPadding: 10, cardPadding: 11,
  railHeight: 42, actionHeight: 48, headerHeight: 28,
  contentWidth: Infinity, previewColumn: 0, layout: "column",
};

/** GeneratorMetrics.expanded — an iPad held upright, or a tall Mac window. */
export const METRICS_EXPANDED = {
  preview: 360, tile: 64, swatch: 58,
  tokenWidth: 94, tokenHeight: 60,
  tileGap: 14, labelGap: 7, rowGap: 15, sectionGap: 17,
  panelPadding: 18, cardPadding: 19,
  railHeight: 60, actionHeight: 62, headerHeight: 34,
  contentWidth: 640, previewColumn: 0, layout: "column",
};

/** GeneratorMetrics.split — wide and short: settings beside the code. */
export const METRICS_SPLIT = {
  preview: 300, tile: 60, swatch: 54,
  tokenWidth: 86, tokenHeight: 56,
  tileGap: 12, labelGap: 6, rowGap: 13, sectionGap: 15,
  panelPadding: 16, cardPadding: 17,
  railHeight: 56, actionHeight: 58, headerHeight: 32,
  contentWidth: 940, previewColumn: 358, layout: "split",
};

/**
 * `GeneratorMetrics.fitting(width:height:)`, line for line.
 *
 * This is the function that decides what a screenshot shows, so it is the one
 * worth keeping identical: a scene asks for the canvas it is drawing and gets
 * the same preset the app would pick for it.
 */
export function fittingMetrics(width, height) {
  if (width < 700 || height < 700) {
    return height < 700 ? METRICS_COMPACT : METRICS;
  }

  if (height >= width) {
    const metrics = { ...METRICS_EXPANDED };
    metrics.preview = Math.min(480, metrics.preview + Math.max(0, height - 1080) * 0.55);
    return metrics;
  }

  const metrics = { ...METRICS_SPLIT };
  metrics.preview = Math.min(420, metrics.preview + Math.max(0, height - 760) * 0.45);
  metrics.previewColumn = metrics.preview + metrics.cardPadding * 2 + 24;
  return metrics;
}

/**
 * `GeneratorMetrics.launchWidth` — the empty state is one card and a sentence,
 * so it takes the narrower cap. An iPad on its side should not stretch a drop
 * target across 940pt.
 */
export function launchWidthFor(m) {
  return Number.isFinite(m.contentWidth) ? Math.min(m.contentWidth, 640) : m.contentWidth;
}

export function esc(s) {
  return String(s)
    .replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

/** Squircle-ish rounded rect. SVG has no continuous corners, so radius carries it. */
function rrect(x, y, w, h, r, attrs) {
  return `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" ry="${r}" ${attrs}/>`;
}

export function text(x, y, content, {
  size = 15, weight = 400, fill = INK.label, anchor = "start",
  opacity = 1, tracking = 0, family = FONT, uppercase = false,
} = {}) {
  const value = uppercase ? String(content).toUpperCase() : content;
  return `<text x="${x}" y="${y}" font-family="${family}" font-size="${size}" font-weight="${weight}"` +
    ` fill="${fill}" text-anchor="${anchor}" opacity="${opacity}"` +
    (tracking ? ` letter-spacing="${tracking}"` : "") +
    `>${esc(value)}</text>`;
}

// MARK: - Glyphs (ShapeGlyphs.swift)

/**
 * AppMarkGlyph — three concentric rings and four data dots, on a 24-unit grid.
 */
export function appMark(x, y, size, color) {
  const u = size / 24;
  const rings = [[7, 7], [17, 7], [7, 17]].map(([cx, cy]) =>
    `<circle cx="${x + cx * u}" cy="${y + cy * u}" r="${4.6 * u}" fill="none" stroke="${color}" stroke-width="${2.3 * u}"/>`
  ).join("");
  const dots = [[14.5, 14.5, 1], [19.5, 14.5, 0.6], [14.5, 19.5, 0.6], [19.5, 19.5, 1]].map(
    ([cx, cy, a]) => `<circle cx="${x + cx * u}" cy="${y + cy * u}" r="${1.5 * u}" fill="${color}" opacity="${a}"/>`
  ).join("");
  return `<g>${rings}${dots}</g>`;
}

/**
 * ModuleShapeGlyph — six modules of a 3×3 excerpt, so every roundness step reads
 * differently. A full block would merge into one square at roundness 0.
 */
export function moduleShapeGlyph(x, y, size, roundness, color = INK.glyph) {
  const cell = size / 3;
  const r = (cell / 2) * roundness;
  const pattern = [[0, 0], [2, 0], [0, 1], [1, 1], [1, 2], [2, 2]];
  return `<g>${pattern.map(([col, row]) =>
    rrect(x + col * cell, y + row * cell, cell, cell, r, `fill="${color}"`)
  ).join("")}</g>`;
}

const EYE_FRACTION = { square: 0, rounded: 0.45, dot: 1.0, leaf: 1.0 };

/** One eye sub-rect. `leaf` keeps the top-left corner sharp, as the renderer does. */
function eyeSubPath(x, y, w, style) {
  const r = Math.min((w / 2) * (EYE_FRACTION[style] ?? 0), w / 2);
  if (r <= 0) return `M${x},${y}h${w}v${w}h${-w}z`;
  if (style === "leaf") {
    return `M${x},${y}` +
      `H${x + w - r}A${r},${r} 0 0 1 ${x + w},${y + r}` +
      `V${y + w - r}A${r},${r} 0 0 1 ${x + w - r},${y + w}` +
      `H${x + r}A${r},${r} 0 0 1 ${x},${y + w - r}Z`;
  }
  return `M${x},${y + r} a${r},${r} 0 0 1 ${r},${-r} h${w - 2 * r} a${r},${r} 0 0 1 ${r},${r}` +
    ` v${w - 2 * r} a${r},${r} 0 0 1 ${-r},${r} h${-(w - 2 * r)} a${r},${r} 0 0 1 ${-r},${-r}z`;
}

/** A whole eye — ring, cutout and pupil — as one even-odd path (QRGlyph.eye). */
export function eyePath(x, y, w, style) {
  const ring = w / 7;
  return [
    [x, y, w],
    [x + ring, y + ring, w - 2 * ring],
    [x + 2 * ring, y + 2 * ring, w - 4 * ring],
  ].filter(([, , side]) => side > 0)
    .map(([sx, sy, side]) => eyeSubPath(sx, sy, side, style))
    .join("");
}

export function eyeShapeGlyph(x, y, size, style, color = INK.glyph) {
  return `<path d="${eyePath(x, y, size, style)}" fill="${color}" fill-rule="evenodd"/>`;
}

/**
 * EyeScaleGlyph — the eye inside its dashed 7×7 slot, so the tile shows a ratio
 * rather than a percentage. Exaggerated the same way the app exaggerates it.
 */
export function eyeScaleGlyph(x, y, size, scale) {
  const drawn = Math.min(1, Math.max(0.2, 0.55 + (scale - 0.75) * 1.8));
  const inset = (size * (1 - drawn * 0.82)) / 2;
  return `<g>
    ${rrect(x + 0.5, y + 0.5, size - 1, size - 1, size * 0.14,
      `fill="none" stroke="${INK.hairline}" stroke-width="1" stroke-dasharray="2.5 2"`)}
    <path d="${eyePath(x + inset, y + inset, size - inset * 2, "rounded")}" fill="${INK.glyph}" fill-rule="evenodd"/>
  </g>`;
}

/** BackgroundGlyph — white paper, or the checkerboard that means transparent. */
export function backgroundGlyph(x, y, size, type) {
  const r = size * 0.22;
  const cell = size / 4;
  let squares = "";
  if (type !== "white") {
    for (let row = 0; row < 4; row += 1) {
      for (let col = 0; col < 4; col += 1) {
        if ((row + col) % 2 !== 0) continue;
        squares += `<rect x="${x + col * cell}" y="${y + row * cell}" width="${cell}" height="${cell}" fill="${INK.hairline}" opacity="0.55"/>`;
      }
    }
  }
  const clipId = `bgClip${Math.round(x * 7 + y * 13 + size)}`;
  return `<g>
    <defs><clipPath id="${clipId}">${rrect(x, y, size, size, r, "")}</clipPath></defs>
    ${rrect(x, y, size, size, r, `fill="#ffffff"`)}
    <g clip-path="url(#${clipId})">${squares}</g>
    ${rrect(x, y, size, size, r, `fill="none" stroke="${INK.hairline}" stroke-width="1"`)}
  </g>`;
}

/** CaptionGlyph — a code with, or without, the text line underneath it. */
export function captionGlyph(x, y, size, isOn) {
  const side = isOn ? size * 0.82 : size;
  const cx = x + (size - side) / 2;
  const unit = side / 9;
  const eyes = [[1, 1], [5, 1], [1, 5], [5, 5]].map(([col, row]) =>
    rrect(cx + col * unit, y + row * unit, unit * 3, unit * 3, unit * 0.7 * 3 / 3, `fill="#ffffff"`)
  ).join("");
  const bar = isOn
    ? rrect(x + size * 0.1, y + size - size * 0.1, size * 0.8, size * 0.075, size * 0.0375, `fill="${INK.glyph}" opacity="0.55"`)
    : "";
  return `<g>${rrect(cx, y, side, side, side * 0.16, `fill="${INK.glyph}"`)}${eyes}${bar}</g>`;
}

/**
 * MiniQRGlyph — a saved style's thumbnail. Same deterministic field the app uses
 * (an LCG with the finder slots cleared), so the thumbnail is a style, not data.
 */
const MINI_SIZE = 21;
const MINI_MODULES = (() => {
  const rows = [];
  let seed = 1_987_654_321n;
  const next = () => {
    seed = (seed * 6_364_136_223_846_793_005n + 1_442_695_040_888_963_407n) & 0xFFFFFFFFFFFFFFFFn;
    return Number((seed >> 33n) % 1000n) / 1000;
  };
  for (let i = 0; i < MINI_SIZE; i += 1) {
    rows.push(Array.from({ length: MINI_SIZE }, () => next() < 0.47));
  }
  for (const [row, col] of [[0, 0], [0, MINI_SIZE - 7], [MINI_SIZE - 7, 0]]) {
    for (let dy = -1; dy < 8; dy += 1) {
      for (let dx = -1; dx < 8; dx += 1) {
        if (row + dy < 0 || row + dy >= MINI_SIZE || col + dx < 0 || col + dx >= MINI_SIZE) continue;
        rows[row + dy][col + dx] = false;
      }
    }
  }
  for (let i = 8; i < MINI_SIZE - 8; i += 1) {
    rows[6][i] = i % 2 === 0;
    rows[i][6] = i % 2 === 0;
  }
  return rows;
})();

let miniSerial = 0;

/**
 * @param {{fill?: string, gradient?: {start: string, end: string},
 *          roundness?: number, eyeStyle?: string, eyeScale?: number,
 *          background?: "white" | "transparent"}} style
 */
export function miniQRGlyph(x, y, size, style = {}) {
  const {
    fill = INK.glyph, gradient = null, roundness = 0,
    eyeStyle = "square", eyeScale = 1, background = "white",
  } = style;
  const unit = size / MINI_SIZE;
  const id = `mini${miniSerial += 1}`;
  let paint = fill;
  let defs = "";
  if (gradient) {
    defs = `<defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${gradient.start}"/><stop offset="1" stop-color="${gradient.end}"/>
    </linearGradient></defs>`;
    paint = `url(#${id})`;
  }

  let field = "";
  const r = (unit / 2) * roundness;
  for (let row = 0; row < MINI_SIZE; row += 1) {
    for (let col = 0; col < MINI_SIZE; col += 1) {
      if (!MINI_MODULES[row][col]) continue;
      const mx = x + col * unit;
      const my = y + row * unit;
      field += r > 0
        ? `M${mx},${my + r} a${r},${r} 0 0 1 ${r},${-r} h${unit - 2 * r} a${r},${r} 0 0 1 ${r},${r} v${unit - 2 * r} a${r},${r} 0 0 1 ${-r},${r} h${-(unit - 2 * r)} a${r},${r} 0 0 1 ${-r},${-r}z`
        : `M${mx},${my}h${unit}v${unit}h${-unit}z`;
    }
  }

  const span = unit * 7 * Math.max(0.3, Math.min(eyeScale, 1.15));
  let eyes = "";
  for (const [row, col] of [[0, 0], [0, MINI_SIZE - 7], [MINI_SIZE - 7, 0]]) {
    const midX = x + col * unit + unit * 3.5;
    const midY = y + row * unit + unit * 3.5;
    eyes += eyePath(midX - span / 2, midY - span / 2, span, eyeStyle);
  }

  return `<g>${defs}
    ${background === "white" ? rrect(x, y, size, size, unit, `fill="#ffffff"`) : ""}
    <path d="${field}" fill="${paint}"/>
    <path d="${eyes}" fill="${paint}" fill-rule="evenodd"/>
  </g>`;
}

// MARK: - SettingTile

/**
 * SettingTile — squircle, white at 100% when selected and 68% otherwise, with
 * the app icon's two concentric rings for selection and a corner padlock for Pro.
 *
 * @param {(cx: number, cy: number, side: number) => string} content
 *        Draws the glyph, given the centred content box.
 */
export function settingTile({
  x, y, w = METRICS.tile, h = METRICS.tile,
  selected = false, locked = false, contentScale = 0.61, content,
}) {
  const radius = Math.min(w, h) * 0.3;
  const side = Math.min(w, h) * contentScale;
  const glyph = content
    ? `<g opacity="${locked ? 0.5 : 1}">${content(x + (w - side) / 2, y + (h - side) / 2, side)}</g>`
    : "";

  const rings = selected ? `
    ${rrect(x - 3, y - 3, w + 6, h + 6, radius + 3, `fill="none" stroke="#ffffff" stroke-opacity="0.95" stroke-width="3"`)}
    ${rrect(x - 5.5, y - 5.5, w + 11, h + 11, radius + 5.5, `fill="none" stroke="#ffffff" stroke-opacity="0.34" stroke-width="2.5"`)}
  ` : "";

  const padlock = locked ? `
    <circle cx="${x + w - 9.5}" cy="${y + 9.5}" r="7.5" fill="#ffffff" fill-opacity="0.95"/>
    ${symbol("lock.fill", x + w - 9.5, y + 9.5, 8.5, "#474747", "bold")}
  ` : "";

  return `<g>
    ${rrect(x, y, w, h, radius, `fill="#ffffff" fill-opacity="${selected ? 1 : 0.68}"`)}
    ${glyph}${padlock}${rings}
  </g>`;
}

/** SettingTokenTile — a number or a format acronym keeps its text in every language. */
export function tokenTile({ x, y, token, selected = false, locked = false, m = METRICS }) {
  return settingTile({
    x, y, w: m.tokenWidth, h: m.tokenHeight, selected, locked, contentScale: 0.86,
    content: (gx, gy, side) => text(gx + side / 2, gy + side / 2 + 4.5, token, {
      size: 13, weight: 600, fill: INK.glyph, anchor: "middle",
    }),
  });
}

/** SettingRowLabel — one uppercase label per row, instead of one per option. */
export function rowLabel(x, y, label) {
  return text(x, y, label, {
    size: 10.5, weight: 600, fill: "#ffffff", opacity: 0.72, tracking: 0.7, uppercase: true,
  });
}

// MARK: - The customization rail

export const FAMILIES = ["styles", "color", "shape", "brand", "export"];

const FAMILY_SYMBOL = {
  styles: "star", color: "paintpalette", shape: null,
  brand: "photo", export: "square.and.arrow.down",
};

/** ModuleMixGlyph — two square modules and two round ones, the rail's shape icon. */
function moduleMixGlyph(x, y, size, color) {
  const cell = size / 2;
  const inset = cell * 0.11;
  const corners = [0.5, 0.16, 0.16, 0.5];
  return corners.map((fraction, index) => {
    const side = cell - inset * 2;
    return rrect(
      x + (index % 2) * cell + inset,
      y + Math.floor(index / 2) * cell + inset,
      side, side, side * fraction, `fill="${color}"`
    );
  }).join("");
}

/** CustomizationRail.familyRail — five buttons, the active one white with a ring. */
export function familyRail({ x, y, width, active = "shape", m = METRICS }) {
  const gap = m.tileGap - 1;
  const button = (width - gap * (FAMILIES.length - 1)) / FAMILIES.length;

  return `<g>${FAMILIES.map((family, index) => {
    const bx = x + (button + gap) * index;
    const isActive = family === active;
    const tint = isActive ? INK.railActive : "#ffffff";
    const icon = FAMILY_SYMBOL[family]
      ? symbol(FAMILY_SYMBOL[family], bx + button / 2, y + m.railHeight / 2, 18, tint, "medium")
      : moduleMixGlyph(bx + button / 2 - 10, y + m.railHeight / 2 - 10, 20, tint);
    const ring = isActive
      ? rrect(bx - 3, y - 3, button + 6, m.railHeight + 6, 19, `fill="none" stroke="#ffffff" stroke-opacity="0.9" stroke-width="3"`)
      : "";
    return `${rrect(bx, y, button, m.railHeight, 16, `fill="#ffffff" fill-opacity="${isActive ? 1 : 0.18}"`)}${icon}${ring}`;
  }).join("")}</g>`;
}

/** The translucent panel the active family is drawn in. */
export function panel(x, y, width, height, inner) {
  return `<g>
    ${rrect(x, y, width, height, 24, `fill="#ffffff" fill-opacity="0.15"`)}
    ${inner}
  </g>`;
}

// MARK: - Screen chrome

/** GeneratorView.headerSection — the mark, the name, and the help button. */
export function header({ x, y, width, m = METRICS }) {
  const mid = y + m.headerHeight / 2;
  return `<g>
    ${appMark(x, mid - 11, 22, "#ffffff")}
    ${text(x + 31, mid + 5.5, "Radical QR", { size: 15, weight: 600, fill: "#ffffff" })}
    <circle cx="${x + width - 17}" cy="${mid}" r="17" fill="#ffffff" fill-opacity="0.18"/>
    ${symbol("questionmark", x + width - 17, mid, 15, "#ffffff", "semibold")}
  </g>`;
}

/** GeneratorView.actionRow — Save QR Code, then copy and share. */
export function actionRow({ x, y, width, label, m = METRICS }) {
  const secondary = m.actionHeight;
  const primary = width - (secondary + m.tileGap) * 2;

  // Icon and label are centred as a pair, from the label's measured width —
  // "Enregistrer le code QR" is half again as long as "Save QR Code", and a
  // fixed icon offset put the two on top of each other. The size drops if the
  // label still will not fit, the way `.minimumScaleFactor` does in the app.
  const icon = 17;
  const gap = 9;
  let size = 16;
  let labelW = estimateTextWidth(label, size);
  const room = primary - 36 - icon - gap;
  if (labelW > room) {
    size = Math.max(11, Math.floor(size * (room / labelW)));
    labelW = estimateTextWidth(label, size);
  }
  const startX = x + primary / 2 - (icon + gap + labelW) / 2;

  return `<g>
    ${rrect(x, y, primary, m.actionHeight, m.actionHeight / 2, `fill="#ffffff"`)}
    ${symbol("square.and.arrow.down", startX + icon / 2, y + m.actionHeight / 2, icon, INK.save, "semibold")}
    ${text(startX + icon + gap, y + m.actionHeight / 2 + size * 0.36, label, {
      size, weight: 600, fill: INK.save,
    })}
    <circle cx="${x + primary + m.tileGap + secondary / 2}" cy="${y + secondary / 2}" r="${secondary / 2}" fill="#ffffff" fill-opacity="0.2"/>
    ${symbol("doc.on.doc", x + primary + m.tileGap + secondary / 2, y + secondary / 2, 18, "#ffffff", "medium")}
    <circle cx="${x + width - secondary / 2}" cy="${y + secondary / 2}" r="${secondary / 2}" fill="#ffffff" fill-opacity="0.2"/>
    ${symbol("square.and.arrow.up", x + width - secondary / 2, y + secondary / 2, 18, "#ffffff", "medium")}
  </g>`;
}

/**
 * GeneratorView.previewCard — the code on white, then the one-line content pill.
 * `qr` is an already-rendered <g> drawn at `previewSize` × `previewSize`.
 */
export function previewCard({
  x, y, width, qr, previewSize, kind, content,
  logo = null, caption = null, m = METRICS,
}) {
  const inner = previewSize + 12;
  const codeX = x + (width - inner) / 2;
  const codeY = y + m.cardPadding;
  const pillY = codeY + inner + m.rowGap;
  const pillH = 30;
  const height = m.cardPadding * 2 + inner + m.rowGap + pillH;

  // A caption is part of the exported image, not a label in the UI: the code
  // gives up the room, exactly as `QRCodeRenderer` makes it.
  const captionBand = caption ? previewSize * 0.13 : 0;
  const codeSide = previewSize - captionBand;
  const codeOffset = (inner - codeSide) / 2;

  // The renderer clears a quiet zone before drawing the logo, so the white
  // square under it is part of the code, not a sticker on top of it.
  const logoSide = codeSide * 0.22;
  const logoCX = codeX + inner / 2;
  const logoCY = codeY + codeOffset + codeSide / 2;
  const logoBlock = logo ? `
    ${rrect(logoCX - logoSide * 0.72, logoCY - logoSide * 0.72,
      logoSide * 1.44, logoSide * 1.44, logoSide * 0.34, `fill="#ffffff"`)}
    ${logo(logoCX - logoSide / 2, logoCY - logoSide / 2, logoSide)}` : "";

  const captionBlock = caption
    ? text(x + width / 2, codeY + codeOffset + codeSide + captionBand * 0.62, caption, {
        size: captionBand * 0.52, weight: 600, fill: INK.glyph, anchor: "middle", tracking: 0.2,
      })
    : "";

  return `<g>
    ${rrect(x, y, width, height, 26, `fill="#ffffff"`)}
    ${rrect(codeX, codeY, inner, inner, 14, `fill="#ffffff"`)}
    <g transform="translate(${codeX + codeOffset} ${codeY + codeOffset})">${qr}</g>
    ${logoBlock}${captionBlock}
    ${rrect(x + m.cardPadding, pillY, width - m.cardPadding * 2, pillH, 15, `fill="#F1F0F6"`)}
    ${text(x + m.cardPadding + 12, pillY + 19.5, kind, { size: 11, weight: 700, fill: INK.railActive, tracking: 0.5, uppercase: true })}
    ${text(x + m.cardPadding + 12 + kind.length * 7.2 + 10, pillY + 19.5, content, { size: 12.5, weight: 500, fill: INK.secondary })}
  </g>`;
}

// MARK: - Launch card

/**
 * LaunchCard — the dashed target, the field, and the three capsules content
 * actually arrives through. `duplicate` carries the 2.0 headline feature, so it
 * is drawn in the middle where the eye lands.
 */
const LAUNCH_PAD = 18;
const LAUNCH_TARGET_H = 164;
const LAUNCH_FIELD_H = 46;
const LAUNCH_CAPSULE_H = 36;
const LAUNCH_CAPSULE_GAP = 12;

/**
 * `LaunchCard.entryRow` is a `ViewThatFits`: three capsules on one row, or two
 * rows when they do not fit. They do not fit in French — "Parcourir les
 * fichiers" is twice the length of "Browse Files" — so the layout has to be
 * decided from the strings, not fixed to the English case.
 *
 * @returns {{stacked: boolean, height: number}}
 */
export function launchCardMetrics(copy, width) {
  const inner = width - LAUNCH_PAD * 2;
  const oneRow = (inner - LAUNCH_CAPSULE_GAP * 2) / 3;
  const labels = [copy.paste, copy.duplicate, copy.browse];
  // 13pt icon, 6pt gap, 10pt padding each side, and `.minimumScaleFactor(0.8)`.
  const room = oneRow - 20 - 13 - 6;
  const stacked = labels.some((label) => estimateTextWidth(label, 12.5 * 0.8) > room);

  const rows = stacked ? 2 : 1;
  const capsules = LAUNCH_CAPSULE_H * rows + (stacked ? 10 : 0);
  return {
    stacked,
    height: LAUNCH_PAD * 2 + LAUNCH_TARGET_H + 16 + LAUNCH_FIELD_H + 16 + capsules,
  };
}

export function launchCard({ x, y, width, copy, m = METRICS }) {
  const pad = LAUNCH_PAD;
  const targetX = x + pad;
  const targetW = width - pad * 2;
  const targetH = LAUNCH_TARGET_H;
  const targetY = y + pad;

  const fieldY = targetY + targetH + 16;
  const fieldH = LAUNCH_FIELD_H;

  const capsuleY = fieldY + fieldH + 16;
  const capsuleH = LAUNCH_CAPSULE_H;
  const gap = LAUNCH_CAPSULE_GAP;
  const { stacked, height } = launchCardMetrics(copy, width);

  // Same measured centring as the save row: these capsules are the narrowest
  // thing on the screen, and a fixed icon offset overlapped the label.
  const capsule = (cx, cy, w, label, icon) => {
    const iconSize = 13;
    const iconGap = 6;
    let size = 12.5;
    let labelW = estimateTextWidth(label, size);
    const room = w - 20 - iconSize - iconGap;
    if (labelW > room) {
      size = Math.max(size * 0.8, size * (room / labelW));
      labelW = estimateTextWidth(label, size);
    }
    const startX = cx + w / 2 - (iconSize + iconGap + labelW) / 2;
    return `
      ${rrect(cx, cy, w, capsuleH, capsuleH / 2, `fill="${INK.accent}"`)}
      ${symbol(icon, startX + iconSize / 2, cy + capsuleH / 2, iconSize, "#ffffff", "medium")}
      ${text(startX + iconSize + iconGap, cy + capsuleH / 2 + size * 0.36, label, {
        size, weight: 500, fill: "#ffffff",
      })}`;
  };

  let capsules;
  if (stacked) {
    const half = (targetW - gap) / 2;
    capsules =
      capsule(targetX, capsuleY, half, copy.paste, "doc.on.clipboard") +
      capsule(targetX + half + gap, capsuleY, half, copy.duplicate, "qrcode.viewfinder") +
      capsule(targetX, capsuleY + capsuleH + 10, targetW, copy.browse, "folder");
  } else {
    const third = (targetW - gap * 2) / 3;
    capsules =
      capsule(targetX, capsuleY, third, copy.paste, "doc.on.clipboard") +
      capsule(targetX + third + gap, capsuleY, third, copy.duplicate, "qrcode.viewfinder") +
      capsule(targetX + (third + gap) * 2, capsuleY, third, copy.browse, "folder");
  }

  return `<g>
    ${rrect(x, y, width, height, 28, `fill="#ffffff"`)}
    ${rrect(targetX, targetY, targetW, targetH, 22,
      `fill="none" stroke="#8E8E93" stroke-opacity="0.28" stroke-width="2" stroke-dasharray="6 5"`)}
    ${appMark(x + width / 2 - 33, targetY + 20, 66, INK.markIdle)}
    ${text(x + width / 2, targetY + 106, copy.launchHeadline, {
      size: 17, weight: 600, fill: INK.label, anchor: "middle",
    })}
    ${wrapped(x + width / 2, targetY + 126, copy.launchSubhead, {
      size: 11.5, fill: INK.secondary, anchor: "middle", maxChars: 44, lineHeight: 14,
    })}
    ${rrect(targetX, fieldY, targetW, fieldH, 13, `fill="#F1F0F6"`)}
    ${text(targetX + 14, fieldY + fieldH / 2 + 5, copy.placeholder, { size: 13.5, fill: "#9A9AA0" })}
    ${capsules}
  </g>`;
}

/** Naive word wrap — enough for the two short lines a mockup ever needs. */
export function wrapped(x, y, content, { maxChars = 40, lineHeight = 16, ...opts } = {}) {
  const words = String(content).split(/\s+/);
  const lines = [];
  let line = "";
  for (const word of words) {
    if (line && (line + " " + word).length > maxChars) {
      lines.push(line);
      line = word;
    } else {
      line = line ? `${line} ${word}` : word;
    }
  }
  if (line) lines.push(line);
  return lines.map((l, i) => text(x, y + i * lineHeight, l, opts)).join("");
}

// MARK: - Screen assembly

/**
 * Draw an app screen in points and place it inside a device frame.
 *
 * The gradient is the app's own, so it continues the poster's background rather
 * than cutting a rectangle out of it.
 */
export function appScreen({ screen, points, gradientId, body }) {
  const scale = screen.w / points.w;
  return `<g clip-path="url(#${gradientId}Clip)">
    <rect x="${screen.x}" y="${screen.y}" width="${screen.w}" height="${screen.h}" fill="url(#${gradientId})"/>
    <g transform="translate(${screen.x} ${screen.y}) scale(${scale})">${body}</g>
  </g>`;
}

/** The clip + gradient an `appScreen` needs in <defs>. */
export function appScreenDefs({ screen, gradientId, radius }) {
  return `
    <clipPath id="${gradientId}Clip">
      <rect x="${screen.x}" y="${screen.y}" width="${screen.w}" height="${screen.h}" rx="${radius}" ry="${radius}"/>
    </clipPath>
    <linearGradient id="${gradientId}" x1="${screen.x}" y1="${screen.y}"
      x2="${screen.x + screen.w}" y2="${screen.y + screen.h}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${INK.gradientStart}"/>
      <stop offset="1" stop-color="${INK.gradientEnd}"/>
    </linearGradient>`;
}

// MARK: - The five families, as the rail draws them

/**
 * Lay out labelled rows of tiles inside the translucent panel.
 *
 * Each row is `{ label, tiles: [{ selected, locked, w, h, draw }] }`. Returns
 * the panel markup and its height, because a scene needs the height to place
 * whatever comes next.
 *
 * @returns {{svg: string, height: number}}
 */
export function familyPanel({ x, y, width, rows, m = METRICS }) {
  const LABEL_H = 13;
  let cursor = y + m.panelPadding;
  let body = "";

  // `TileRow` is a horizontal ScrollView, so a row wider than the panel really
  // is cut off in the app — seven colour swatches on a 375pt screen are. Clip to
  // the same bounds rather than letting a tile spill over the panel's corner.
  const clipId = `rowClip${Math.round(x * 31 + y * 17 + width)}`;
  let clips = `<defs><clipPath id="${clipId}"><rect x="${x + m.panelPadding - 7}" y="${y}"
    width="${width - (m.panelPadding - 7) * 2}" height="10000"/></clipPath></defs>`;

  const visible = width - m.panelPadding * 2;

  for (const row of rows) {
    const tileH = row.tiles[0]?.h ?? m.tile;
    const widths = row.tiles.map((t) => t.w ?? m.tile);
    const rowWidth = widths.reduce((a, b) => a + b, 0) + m.tileGap * (widths.length - 1);

    // A ScrollView shows its selection: when the row is wider than the panel,
    // scroll far enough right that the selected tile is whole. Without this the
    // export scene would clip away the very options it is there to show.
    let scroll = 0;
    if (rowWidth > visible) {
      const index = row.tiles.findIndex((t) => t.selected);
      if (index >= 0) {
        const right = widths.slice(0, index + 1).reduce((a, b) => a + b, 0) + m.tileGap * index;
        scroll = Math.max(0, Math.min(rowWidth - visible, right - visible + 4));
      }
    }

    body += rowLabel(x + m.panelPadding, cursor + 9, row.label);
    let tx = x + m.panelPadding - scroll;
    let tiles = "";
    for (const [i, tile] of row.tiles.entries()) {
      tiles += settingTile({
        x: tx, y: cursor + LABEL_H + m.labelGap, w: widths[i], h: tile.h ?? m.tile,
        selected: tile.selected, locked: tile.locked,
        contentScale: tile.contentScale, content: tile.draw,
      });
      tx += widths[i] + m.tileGap;
    }
    body += `<g clip-path="url(#${clipId})">${tiles}</g>`;
    cursor += LABEL_H + m.labelGap + tileH + m.rowGap;
  }
  body = clips + body;

  const height = cursor - m.rowGap + m.panelPadding - y;
  return { svg: panel(x, y, width, height, body), height };
}

/** ShapeGroupView — module corners, eye shape, eye size. */
export function shapeFamily({ x, y, width, copy, selection = {}, m = METRICS }) {
  const { roundness = 0.6, eyeStyle = "leaf", eyeScale = 0.9 } = selection;
  return familyPanel({
    x, y, width, m,
    rows: [
      {
        label: copy.labelModules,
        tiles: [0, 0.3, 0.6, 1.0].map((step) => ({
          selected: Math.abs(step - roundness) < 0.05,
          draw: (gx, gy, side) => moduleShapeGlyph(gx, gy, side, step),
        })),
      },
      {
        label: copy.labelEyes,
        tiles: ["square", "rounded", "dot", "leaf"].map((style) => ({
          selected: style === eyeStyle,
          draw: (gx, gy, side) => eyeShapeGlyph(gx, gy, side, style),
        })),
      },
      {
        label: copy.labelEyeSize,
        tiles: [0.75, 0.9, 1.0].map((step) => ({
          selected: Math.abs(step - eyeScale) < 0.05,
          draw: (gx, gy, side) => eyeScaleGlyph(gx, gy, side, step),
        })),
      },
    ],
  });
}

/** SerializableColor.freeColors — the six the free tier gets. */
export const FREE_COLORS = ["#000000", "#1E3A5F", "#2D5A3D", "#722F37", "#36454F", "#4B0082"];
/** GradientConfiguration.freeGradients. */
export const FREE_GRADIENTS = [
  { start: "#667EEA", end: "#764BA2" },
  { start: "#3B82F6", end: "#38C8D5" },
  { start: "#F97316", end: "#EC4E8D" },
];

/** ColorGroupView — solids, gradients, background. The last tile of each row is Pro. */
export function colorFamily({ x, y, width, copy, selection = {}, m = METRICS }) {
  const { gradient = 0, background = "white" } = selection;
  const swatch = (fill) => (gx, gy, side) =>
    `<circle cx="${gx + side / 2}" cy="${gy + side / 2}" r="${side / 2}" fill="${fill}"/>`;

  let wheelSerial = 0;
  const wheel = (gx, gy, side) => {
    const id = `wheel${wheelSerial += 1}`;
    const stops = ["#FF3B30", "#FFCC00", "#34C759", "#00C7BE", "#007AFF", "#AF52DE", "#FF3B30"];
    return `<defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">${
      stops.map((c, i) => `<stop offset="${i / (stops.length - 1)}" stop-color="${c}"/>`).join("")
    }</linearGradient></defs>
    <circle cx="${gx + side / 2}" cy="${gy + side / 2}" r="${side / 2}" fill="url(#${id})"/>`;
  };

  let gradSerial = 0;
  const gradientSwatch = (preset) => (gx, gy, side) => {
    const id = `gsw${gradSerial += 1}`;
    return `<defs><linearGradient id="${id}" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${preset.start}"/><stop offset="1" stop-color="${preset.end}"/>
    </linearGradient></defs>
    <circle cx="${gx + side / 2}" cy="${gy + side / 2}" r="${side / 2}" fill="url(#${id})"/>`;
  };

  return familyPanel({
    x, y, width, m,
    rows: [
      {
        label: copy.labelSolid,
        tiles: [
          ...FREE_COLORS.map((color) => ({
            w: m.swatch, h: m.swatch, contentScale: 0.64, selected: false, draw: swatch(color),
          })),
          { w: m.swatch, h: m.swatch, contentScale: 0.64, locked: true, draw: wheel },
        ],
      },
      {
        label: copy.labelGradient,
        tiles: [
          ...FREE_GRADIENTS.map((preset, i) => ({
            w: m.swatch, h: m.swatch, contentScale: 0.64,
            selected: i === gradient, draw: gradientSwatch(preset),
          })),
          { w: m.swatch, h: m.swatch, contentScale: 0.64, locked: true, draw: wheel },
        ],
      },
      {
        label: copy.labelBackground,
        tiles: ["white", "transparent"].map((type) => ({
          selected: type === background,
          draw: (gx, gy, side) => backgroundGlyph(gx, gy, side, type),
        })),
      },
    ],
  });
}

/** BrandGroupView — the logo well and the caption switch, both Pro. */
export function brandFamily({ x, y, width, copy, selection = {}, m = METRICS }) {
  const { hasLogo = true, caption = true, isPro = true } = selection;
  const logoWell = (gx, gy, side) => `
    ${hasLogo
      ? appMark(gx + side * 0.08, gy + side * 0.08, side * 0.84, INK.railActive)
      : `<path d="M${gx + side / 2},${gy + side * 0.18} V${gy + side * 0.82} M${gx + side * 0.18},${gy + side / 2} H${gx + side * 0.82}"
           stroke="${INK.hairline}" stroke-width="${side * 0.09}" stroke-linecap="round"/>`}`;

  return familyPanel({
    x, y, width, m,
    rows: [
      {
        label: copy.labelLogo,
        tiles: [
          { selected: hasLogo, locked: !isPro, draw: logoWell },
          { selected: !hasLogo, locked: !isPro, draw: (gx, gy, side) => miniQRGlyph(gx, gy, side, { roundness: 0.6, eyeStyle: "leaf" }) },
        ],
      },
      {
        label: copy.labelCaption,
        tiles: [false, true].map((isOn) => ({
          selected: isOn === caption,
          draw: (gx, gy, side) => captionGlyph(gx, gy, side, isOn),
        })),
      },
    ],
  });
}

/** CustomizationRail.exportGroup — sizes, then formats. PDF and SVG are Pro. */
export function exportFamily({ x, y, width, copy, selection = {}, m = METRICS }) {
  const { size = "1024", format = "SVG", isPro = false } = selection;
  const sizes = copy.sizes ?? ["256", "512", "1024", "2048", "4096"];
  const formats = copy.formats ?? ["PNG", "JPEG", "WEBP", "PDF", "SVG"];

  const token = (label) => (gx, gy, side) =>
    text(gx + side / 2, gy + side / 2 + 4.5, label, {
      size: 13, weight: 600, fill: INK.glyph, anchor: "middle",
    });

  return familyPanel({
    x, y, width, m,
    rows: [
      {
        label: copy.labelSize,
        tiles: sizes.map((value) => ({
          w: m.tokenWidth, h: m.tokenHeight, contentScale: 0.86,
          selected: value === size,
          locked: !isPro && Number(value) > 400,
          draw: token(value),
        })),
      },
      {
        label: copy.labelFormat,
        tiles: formats.map((value) => ({
          w: m.tokenWidth, h: m.tokenHeight, contentScale: 0.86,
          selected: value === format,
          locked: !isPro && (value === "PDF" || value === "SVG"),
          draw: token(value),
        })),
      },
    ],
  });
}

/** SavedStylesStrip — the user's own styles, as MiniQR thumbnails. */
export function stylesFamily({ x, y, width, copy, styles, selected = 0, m = METRICS }) {
  return familyPanel({
    x, y, width, m,
    rows: [{
      label: copy.labelMyStyles,
      tiles: styles.map((style, i) => ({
        w: m.swatch, h: m.swatch, contentScale: 0.78,
        selected: i === selected,
        draw: (gx, gy, side) => miniQRGlyph(gx, gy, side, style),
      })),
    }],
  });
}

// MARK: - Odds and ends the generator screen still needs

/**
 * GeneratorView.privacyNote — a shield and one line, centred as a unit.
 *
 * SVG cannot measure text, so the icon is placed from an estimated width. SF at
 * 12pt averages close to 0.485em, and being a point or two off only shifts the
 * pair; it never overlaps, which is what a fixed offset did.
 */
export function inlineNote({ centerX, y, label, size = 12, icon = "lock.shield", opacity = 0.78 }) {
  const labelW = String(label).length * size * 0.485;
  const gap = size * 0.5;
  const startX = centerX - (size + gap + labelW) / 2;
  return `<g opacity="${opacity}">
    ${symbol(icon, startX + size / 2, y - size * 0.34, size, "#ffffff", "regular")}
    ${text(startX + size + gap, y, label, { size, fill: "#ffffff" })}
  </g>`;
}

/**
 * RecentHistoryStrip — 64pt thumbnails under a "Recent" label. Pro only, which
 * is why it only appears on scenes that are showing a Pro screen.
 *
 * Each item carries its own rendered code (`qr`, drawn at `thumb - 12`), not a
 * schematic: these are four different payloads in the app, so four identical
 * patterns would read as a mock-up rather than a screen.
 *
 * @returns {{svg: string, height: number}}
 */
export function recentStrip({ x, y, width, label, items }) {
  const thumb = 64;
  const gap = 10;
  const labelH = 14;
  const captionH = 15;
  const top = y + labelH + 8;

  const cells = items.map((item, i) => {
    const cx = x + 4 + (thumb + gap) * i;
    if (cx + thumb > x + width) return "";
    return `
      ${rrect(cx, top, thumb, thumb, 8, `fill="#ffffff"`)}
      <g transform="translate(${cx + 6} ${top + 6})">${item.qr}</g>
      ${rrect(cx, top, thumb, thumb, 8, `fill="none" stroke="#ffffff" stroke-opacity="0.2" stroke-width="1"`)}
      ${text(cx, top + thumb + 11, ellipsize(item.label, thumb, 9), { size: 9, fill: "#ffffff", opacity: 0.75 })}`;
  }).join("");

  return {
    svg: `<g>${text(x + 4, y + 10, label, { size: 11, weight: 500, fill: "#ffffff", opacity: 0.8 })}${cells}</g>`,
    height: labelH + 8 + thumb + captionH,
  };
}

/**
 * SwiftUI's `.lineLimit(1)` in a renderer that cannot measure text: cut to what
 * fits `width` at `size`, assuming SF's ~0.5em average. Better a clean ellipsis
 * than four captions running into each other.
 */
export function ellipsize(label, width, size) {
  const max = Math.floor(width / (size * 0.5));
  const value = String(label);
  return value.length <= max ? value : `${value.slice(0, Math.max(1, max - 1))}…`;
}

// MARK: - Measuring text without a text engine

/**
 * Estimated advance widths, in ems, for SF Pro at display weights.
 *
 * SVG has no way to ask how wide a string will be, and the posters go out in ten
 * languages: a headline tuned by eye in English runs off the canvas in German
 * and stays half-empty in Japanese. This table is coarse — three buckets and a
 * CJK case — but it is enough to pick a font size that always fits, which is the
 * only decision it feeds.
 */
const NARROW = new Set([..."ijltfrIJ.,;:!|'’\"()[]{}·-"]);
const WIDE = new Set([..."mwMWQO@%"]);
const UPPER = /[A-ZÀ-ÖØ-Þ]/;

function advance(char) {
  const code = char.codePointAt(0);
  if (char === " ") return 0.26;
  // CJK and Kana are full-width; Hangul too.
  if (code >= 0x2e80 && code <= 0xd7ff) return 1;
  if (code >= 0xff00 && code <= 0xff60) return 1;
  if (NARROW.has(char)) return 0.28;
  if (WIDE.has(char)) return 0.85;
  if (UPPER.test(char)) return 0.62;
  if (code >= 0x30 && code <= 0x39) return 0.55;
  if (code > 0x7f) return 0.55;
  return 0.52;
}

/** Calibrated against rendered SF Pro Display Bold, which sits ~5% under the sum. */
export function estimateTextWidth(content, size) {
  let ems = 0;
  for (const char of String(content)) ems += advance(char);
  return ems * size * 0.95;
}

/**
 * The largest size at or below `base` at which every line fits `maxWidth`.
 * Never grows text: a short headline should stay at the series' size, not swell.
 */
export function fitFontSize(lines, maxWidth, base) {
  const widest = Math.max(...lines.filter(Boolean).map((l) => estimateTextWidth(l, base)), 1);
  return widest <= maxWidth ? base : Math.floor(base * (maxWidth / widest));
}
