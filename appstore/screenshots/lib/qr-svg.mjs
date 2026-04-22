/**
 * qr-svg.mjs — produce a QR code as an SVG <g> that mirrors the app's
 * `QRCodeRenderer` styling:
 *   • gradient or solid foreground
 *   • independent `roundness` for data modules
 *   • independent `eyeRoundness` + `eyeScale` for finder patterns
 *   • optional background color
 *
 * Usage:
 *   import { renderQR } from "./lib/qr-svg.mjs";
 *   const svgGroup = renderQR({
 *     content: "https://example.com",
 *     size: 512,
 *     roundness: 0.3,
 *     eyeRoundness: 1.0,
 *     eyeScale: 0.9,
 *     gradient: { start: "#667eea", end: "#764ba2", angle: 135 },
 *     errorCorrection: "H",
 *   });
 */

import pkg from "qrcode-generator";
const qrcode = pkg.default ?? pkg;

/**
 * Build the QR matrix using qrcode-generator.
 * Returns a 2D boolean array — true = dark module.
 */
function buildMatrix(content, errorCorrection = "M") {
  // Type 0 = auto size, pass correction level as 'L' | 'M' | 'Q' | 'H'
  const qr = qrcode(0, errorCorrection);
  qr.addData(content);
  qr.make();
  const size = qr.getModuleCount();
  const matrix = [];
  for (let r = 0; r < size; r++) {
    const row = [];
    for (let c = 0; c < size; c++) row.push(qr.isDark(r, c));
    matrix.push(row);
  }
  return matrix;
}

/** Is (row, col) inside any finder-pattern region (top-left / top-right / bottom-left, 7×7). */
function isInFinder(row, col, size, patternSize = 7) {
  if (row < patternSize && col < patternSize) return true;
  if (row < patternSize && col >= size - patternSize) return true;
  if (row >= size - patternSize && col < patternSize) return true;
  return false;
}

/** Top-left corners of the 3 finder regions, in module-space. */
function finderRegions(size, patternSize = 7) {
  return [
    [0, 0],
    [0, size - patternSize],
    [size - patternSize, 0],
  ];
}

function esc(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/"/g, "&quot;");
}

/**
 * Renders a QR code as an SVG fragment (a <g> element) centered in a
 * `canvasSize` × `canvasSize` box. The caller is responsible for wrapping
 * it in an <svg> and positioning it.
 */
export function renderQR({
  content,
  size = 512,                    // Target outer canvas size (px)
  quietZone = 1,                 // In modules
  roundness = 0,                 // Data modules: 0..1
  eyeRoundness = 0,              // Finder frames + pupils: 0..1
  eyeScale = 1,                  // Finder frames scaled around center: ~0.7..1.0
  color = "#000",                // Used when `gradient` is absent
  gradient = null,               // { start, end, angle? }
  background = null,             // e.g. "#ffffff" or null for transparent
  errorCorrection = "M",
  gradientId = "qrGradient",
  inset = 0.02,                  // Module inset to prevent touching-edge artifacts
}) {
  const matrix = buildMatrix(content, errorCorrection);
  const n = matrix.length;

  // Layout in pixel space.
  const moduleSize = size / (n + quietZone * 2);
  const offset = quietZone * moduleSize;

  const moduleCornerRadius = moduleSize * roundness * 0.5;
  const moduleInset = moduleSize * inset;

  // --- Defs (gradient + background) ---
  let defs = "";
  let fillRef = color;
  if (gradient) {
    const angle = gradient.angle ?? 135;
    const a = (angle * Math.PI) / 180;
    // Map angle to SVG linearGradient coords on a unit box.
    // start = -dx,-dy from center; end = +dx,+dy; clip to [0,1].
    const dx = 0.5 * Math.cos(a);
    const dy = 0.5 * Math.sin(a);
    const x1 = 0.5 - dx, y1 = 0.5 - dy, x2 = 0.5 + dx, y2 = 0.5 + dy;
    defs += `<linearGradient id="${gradientId}" x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}">
      <stop offset="0" stop-color="${esc(gradient.start)}"/>
      <stop offset="1" stop-color="${esc(gradient.end)}"/>
    </linearGradient>`;
    fillRef = `url(#${gradientId})`;
  }

  // --- Data modules path ---
  let dataPath = "";
  const eyes = finderRegions(n);
  for (let r = 0; r < n; r++) {
    for (let c = 0; c < n; c++) {
      if (!matrix[r][c]) continue;
      if (isInFinder(r, c, n)) continue; // skipped — drawn below as custom shape
      const x = offset + c * moduleSize + moduleInset;
      const y = offset + r * moduleSize + moduleInset;
      const w = moduleSize - moduleInset * 2;
      if (roundness > 0) {
        const rr = Math.min(moduleCornerRadius, w / 2);
        dataPath += `M${x},${y + rr} a${rr},${rr} 0 0 1 ${rr},${-rr} h${w - 2 * rr} a${rr},${rr} 0 0 1 ${rr},${rr} v${w - 2 * rr} a${rr},${rr} 0 0 1 ${-rr},${rr} h${-(w - 2 * rr)} a${rr},${rr} 0 0 1 ${-rr},${-rr}z`;
      } else {
        dataPath += `M${x},${y}h${w}v${w}h${-w}z`;
      }
    }
  }

  // --- Eye paths (even-odd fill so outer ring + pupil are painted correctly) ---
  const eyeClampScale = Math.max(0.3, Math.min(eyeScale, 1.15));
  let eyesPath = "";
  for (const [er, ec] of eyes) {
    const slotX = offset + ec * moduleSize;
    const slotY = offset + er * moduleSize;
    const slotW = 7 * moduleSize;
    // Shrink around center by (1 - scale)
    const shrink = (slotW * (1 - eyeClampScale)) / 2;
    const outerX = slotX + shrink;
    const outerY = slotY + shrink;
    const outerW = slotW - 2 * shrink;
    const ringThickness = moduleSize * eyeClampScale;

    const innerX = outerX + ringThickness;
    const innerY = outerY + ringThickness;
    const innerW = outerW - 2 * ringThickness;

    const pupilX = outerX + 2 * ringThickness;
    const pupilY = outerY + 2 * ringThickness;
    const pupilW = outerW - 4 * ringThickness;

    const roundedRectPath = (x, y, w, rRatio) => {
      const rr = Math.max(0, Math.min((w / 2) * rRatio, w / 2));
      if (rr === 0) return `M${x},${y}h${w}v${w}h${-w}z`;
      return `M${x},${y + rr} a${rr},${rr} 0 0 1 ${rr},${-rr} h${w - 2 * rr} a${rr},${rr} 0 0 1 ${rr},${rr} v${w - 2 * rr} a${rr},${rr} 0 0 1 ${-rr},${rr} h${-(w - 2 * rr)} a${rr},${rr} 0 0 1 ${-rr},${-rr}z`;
    };
    eyesPath += roundedRectPath(outerX, outerY, outerW, eyeRoundness);
    eyesPath += roundedRectPath(innerX, innerY, innerW, eyeRoundness);
    eyesPath += roundedRectPath(pupilX, pupilY, pupilW, eyeRoundness);
  }

  // --- Assemble ---
  const bgRect = background
    ? `<rect x="0" y="0" width="${size}" height="${size}" fill="${esc(background)}"/>`
    : "";

  return `<g>
    ${defs ? `<defs>${defs}</defs>` : ""}
    ${bgRect}
    <path d="${dataPath}" fill="${fillRef}" fill-rule="nonzero"/>
    <path d="${eyesPath}" fill="${fillRef}" fill-rule="evenodd"/>
  </g>`;
}
