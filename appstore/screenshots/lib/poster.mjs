/**
 * poster.mjs — the furniture around the device: badges, bullet lists, and the
 * scene runner every scene ends with.
 *
 * Frames (phone/ipad/mac) own the device; this owns the poster.
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { FONT, esc, estimateTextWidth } from "./app-ui.mjs";
import { symbol } from "./symbols.mjs";

const OUT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "../out");

/** Translucent value chips on one centred row. */
export function badgeRow(chips, cx, cy, { size = 38, scale = 1 } = {}) {
  const fontSize = size * scale;
  const padX = 34 * scale;
  const gap = 26 * scale;
  const height = 78 * scale;
  // Not t.length * 0.56: that is a Latin average, and it sized the Japanese
  // pills at 85 where the text needed 144, so the words sat outside them.
  // estimateTextWidth counts a kanji as a full em, which is what it is.
  const widths = chips.map((t) => estimateTextWidth(t, fontSize) + padX * 2);
  const total = widths.reduce((a, b) => a + b, 0) + gap * (chips.length - 1);
  let x = cx - total / 2;

  return chips.map((chip, i) => {
    const w = widths[i];
    const g = `<g>
      <rect x="${x}" y="${cy - height / 2}" width="${w}" height="${height}" rx="${height / 2}" fill="#ffffff" opacity="0.18"/>
      <text x="${x + w / 2}" y="${cy + fontSize * 0.36}" text-anchor="middle" font-size="${fontSize}"
        font-weight="600" fill="#ffffff" font-family="${FONT}">${esc(chip)}</text>
    </g>`;
    x += w + gap;
    return g;
  }).join("");
}

/** A checked list — used by the privacy scenes, where the points *are* the pitch. */
export function checkList(points, { x, y, lineHeight = 96, size = 44, scale = 1 }) {
  return points.map((point, i) => {
    const cy = y + i * lineHeight * scale;
    return `<g>
      <circle cx="${x + 22 * scale}" cy="${cy - size * scale * 0.32}" r="${22 * scale}" fill="#ffffff" opacity="0.22"/>
      ${symbol("checkmark", x + 22 * scale, cy - size * scale * 0.32, 22 * scale, "#ffffff", "bold")}
      <text x="${x + 60 * scale}" y="${cy}" font-size="${size * scale}" font-weight="500" fill="#ffffff"
        opacity="0.95" font-family="${FONT}">${esc(point)}</text>
    </g>`;
  }).join("");
}

/**
 * Write one scene's SVG. Every scene ends with this, so the naming rule that
 * `appstore-screenshots.mjs` matches on lives in exactly one place.
 */
export function writeScene(name, locale, svg) {
  fs.mkdirSync(OUT, { recursive: true });
  const file = path.join(OUT, `${name}-${locale}.svg`);
  fs.writeFileSync(file, svg);
  console.log("wrote", path.relative(process.cwd(), file));
}
