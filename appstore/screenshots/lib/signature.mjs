/**
 * signature.mjs — the Radical Solution footer every screenshot carries.
 *
 * The App Store shows these as a strip, so the line has to survive being 200px
 * wide in a browsing list: who made it, and what they promise. It is set quietly
 * (white at 58%) because it is a signature, not a claim competing with the
 * headline — the headline sells, this says who is selling.
 *
 * It is one centred `<text>` with tspans rather than positioned pieces: the
 * renderer centres the whole run for us, which is the only layout that survives
 * ten languages. Guessing string widths put the separator inside the words.
 *
 * The promise stays in English in every locale, like the brand name itself — it
 * is the company's signature lockup. `copy/<locale>.json` can still override
 * `signature` where a translation genuinely reads better.
 */

import { FONT, esc } from "./app-ui.mjs";

/**
 * @param {object} options
 * @param {number} options.centerX  Poster centre.
 * @param {number} options.y        Baseline.
 * @param {object} options.copy     Needs `signature` and `signatureBrand`.
 * @param {number} [options.size]   Cap height in canvas pixels.
 */
export function signature({ centerX, y, copy, size = 34 }) {
  const brand = copy.signatureBrand ?? "RadicalSolution.com";
  const promise = copy.signature ?? "Privacy First, Privacy by Design";

  return `<text x="${centerX}" y="${y}" text-anchor="middle" font-family="${FONT}"
    font-size="${size}" fill="#ffffff" opacity="0.58">
    <tspan font-weight="600">${esc(brand)}</tspan><tspan
      dx="${size * 0.5}" opacity="0.6">•</tspan><tspan
      dx="${size * 0.5}" font-weight="400">${esc(promise)}</tspan>
  </text>`;
}
