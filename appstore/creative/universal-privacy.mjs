/**
 * universal-privacy.mjs — la variante « Privacy by design » du visuel
 * universel (voir universal.mjs pour le format et la zone sûre).
 *
 * Toujours sans texte. Les cinq contenus entrent dans un bouclier qui
 * contient la carte QR, un cadenas le scelle ; à droite, trois pictos
 * barrés — nuage, œil, antenne — disent que rien n'en sort : pas de serveur,
 * pas de regard, pas d'envoi. Les filets ne traversent pas le bouclier.
 * universal-shield.mjs combine ce bouclier avec les trois styles.
 *
 *   node universal-privacy.mjs   →  out/universal-privacy.svg
 */

import { symbol } from "../screenshots/lib/symbols.mjs";
import { cx, cy, white, CHIP_R, chip, shield, inputColumn, qrCard, writeSvg } from "./lib.mjs";

// --- Le bouclier, la carte dedans ------------------------------------------------

const guard = shield();
const centre = qrCard({ y: guard.cardY, card: 1060, radius: 90, qr: 880, logo: 220 });

// --- Gauche : ce qui entre. Les filets s'arrêtent au bord du bouclier. --------

const inputs = inputColumn({ x: cx - 1360, lineEnd: cx - guard.hw - 60, converge: 0.3 });

// --- Droite : ce qui ne sort pas -------------------------------------------------

function cloudGlyph(x, y, s) {
  return `<g fill="${white}">
    <circle cx="${x - s * 0.32}" cy="${y + s * 0.12}" r="${s * 0.3}"/>
    <circle cx="${x + s * 0.02}" cy="${y - s * 0.12}" r="${s * 0.4}"/>
    <circle cx="${x + s * 0.4}" cy="${y + s * 0.1}" r="${s * 0.32}"/>
    <rect x="${x - s * 0.32}" y="${y + s * 0.05}" width="${s * 0.72}" height="${s * 0.37}"/>
  </g>`;
}

function eyeGlyph(x, y, s) {
  return `<path fill-rule="evenodd" fill="${white}" d="M ${x - s} ${y} Q ${x} ${y - s * 0.95} ${x + s} ${y} Q ${x} ${y + s * 0.95} ${x - s} ${y} Z
      M ${x} ${y - s * 0.36} a ${s * 0.36} ${s * 0.36} 0 1 0 0.01 0 Z"/>
    <circle cx="${x}" cy="${y}" r="${s * 0.17}" fill="${white}"/>`;
}

function antennaGlyph(x, y, s) {
  const yc = y - s * 0.2;
  const th = (52 * Math.PI) / 180;
  const arc = (side, r) => {
    const x1 = x + side * r * Math.cos(th), y1 = yc - r * Math.sin(th);
    const y2 = yc + r * Math.sin(th);
    return `<path d="M ${x1} ${y1} A ${r} ${r} 0 0 ${side > 0 ? 1 : 0} ${x1} ${y2}"
      stroke="${white}" stroke-width="${s * 0.13}" stroke-linecap="round" fill="none"/>`;
  };
  return `<circle cx="${x}" cy="${yc}" r="${s * 0.15}" fill="${white}"/>
    <line x1="${x}" y1="${yc + s * 0.1}" x2="${x}" y2="${y + s * 0.85}" stroke="${white}" stroke-width="${s * 0.13}" stroke-linecap="round"/>
    ${arc(-1, s * 0.5)}${arc(-1, s * 0.85)}${arc(1, s * 0.5)}${arc(1, s * 0.85)}`;
}

/** Un picto barré à la manière de SF Symbols : le trait, et sa réserve. */
function struck(x, y, draw) {
  const id = `cut${Math.round(y)}`;
  const d = CHIP_R * 0.62;
  const defs = `
    <mask id="${id}">
      <rect x="${x - CHIP_R}" y="${y - CHIP_R}" width="${CHIP_R * 2}" height="${CHIP_R * 2}" fill="#fff"/>
      <line x1="${x - d}" y1="${y - d}" x2="${x + d}" y2="${y + d}" stroke="#000" stroke-width="40" stroke-linecap="round"/>
    </mask>`;
  const body = `
    ${chip(x, y, () => `<g mask="url(#${id})" opacity="0.8">${draw(x, y)}</g>`, { fill: 0.12, stroke: 0.28 })}
    <line x1="${x - d}" y1="${y - d}" x2="${x + d}" y2="${y + d}" stroke="${white}" stroke-width="14" stroke-linecap="round"/>`;
  return { defs, body };
}

const rightX = cx + 1360;
const outGap = 420;
const refusals = [
  (x, y) => cloudGlyph(x, y, 92),
  (x, y) => eyeGlyph(x, y, 84),
  (x, y) => antennaGlyph(x, y, 78),
].map((draw, i) => struck(rightX, cy - outGap + i * outGap, draw));

// --- Assemblage ---------------------------------------------------------------

const defs = inputs.defs + guard.defs + centre.defs + refusals.map((r) => r.defs).join("");
const body = inputs.body + refusals.map((r) => r.body).join("") + guard.outline + centre.body + guard.lock;

writeSvg("universal-privacy", defs, body);
