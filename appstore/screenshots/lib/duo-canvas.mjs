#!/usr/bin/env node
/**
 * duo-canvas.mjs — recadre une scène iPad 13" (2064×2752) sur l'écran intérieur
 * de l'iPhone Duo (2007×2853).
 *
 *   node lib/duo-canvas.mjs out/p01-hero-ipad-fr-FR.svg out/p01-hero-duo-fr-FR.svg
 *
 * L'écran intérieur du Duo (0,70) est presque au format iPad (0,75) : on garde
 * le dessin iPad à pleine largeur et on allonge la toile en haut et en bas.
 * Le fond est redessiné sur toute la hauteur avec le même remplissage que la
 * scène ; le dégradé est en userSpaceOnUse, il se prolonge sans raccord.
 * App Store Connect refuse la transparence pour le Duo : aucune bande vide.
 *
 * Aucune scène n'est modifiée, et le cadre reste celui de l'iPad : quand on aura
 * un dessin du Duo, c'est ici qu'il faudra le brancher.
 *
 * Repris tel quel dans Radical QR et TUV iOS.
 */

import fs from "node:fs";

const DUO_INNER = { w: 2007, h: 2853 };
const IPAD = { w: 2064, h: 2752 };

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  console.error("Usage: node duo-canvas.mjs <ipad.svg> <duo.svg>");
  process.exit(1);
}

const svg = fs.readFileSync(input, "utf8");

// Hauteur de la toile Duo exprimée dans les unités du dessin iPad.
const viewH = (IPAD.w * DUO_INNER.h) / DUO_INNER.w;
const pad = (viewH - IPAD.h) / 2;

const root = /<svg\b[^>]*>/.exec(svg);
if (!root || !root[0].includes(`viewBox="0 0 ${IPAD.w} ${IPAD.h}"`)) {
  console.error(`${input} : pas une scène iPad ${IPAD.w}×${IPAD.h}`);
  process.exit(1);
}

// Le fond plein cadre que chaque frame iPad pose en premier.
const bgRe = new RegExp(`<rect x="0" y="0" width="${IPAD.w}" height="${IPAD.h}" fill="([^"]+)"\\s*/>`);
const bg = bgRe.exec(svg);
if (!bg) {
  console.error(`${input} : fond plein cadre introuvable`);
  process.exit(1);
}

const newRoot = root[0]
  .replace(`viewBox="0 0 ${IPAD.w} ${IPAD.h}"`, `viewBox="0 ${(-pad).toFixed(2)} ${IPAD.w} ${viewH.toFixed(2)}"`)
  .replace(`width="${IPAD.w}"`, `width="${DUO_INNER.w}"`)
  .replace(`height="${IPAD.h}"`, `height="${DUO_INNER.h}"`);

const fullBg = `<rect x="0" y="${(-pad).toFixed(2)}" width="${IPAD.w}" height="${viewH.toFixed(2)}" fill="${bg[1]}"/>`;

const out = svg
  .replace(root[0], newRoot)
  .replace(bg[0], fullBg);

fs.writeFileSync(output, out);
