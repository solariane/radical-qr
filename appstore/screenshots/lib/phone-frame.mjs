/**
 * phone-frame.mjs — shared iPhone 6.9" mockup geometry + SVG helper.
 * Every scene uses the same coordinates so the series looks consistent.
 */

import { appScreen, appScreenDefs, fitFontSize } from "./app-ui.mjs";
import { signature } from "./signature.mjs";

export const CANVAS = { w: 1290, h: 2796 };

export const COLORS = {
  bgStart: "#667eea",
  bgEnd: "#764ba2",
  phoneBezel: "#0f0f18",
  screenBgStart: "#7b8fef",
  screenBgEnd: "#8a5fb8",
  qrGradientStart: "#4D33D9",
  qrGradientEnd: "#8C3BBF",
};

export const FONT = `-apple-system, 'SF Pro Display', 'Helvetica Neue', Helvetica, Arial, sans-serif`;

export const PHONE = {
  w: 820,
  h: 1680,
  x: (CANVAS.w - 820) / 2,
  y: 700,
  bezel: 18,
  radius: 110,
};

export const SCREEN = {
  x: PHONE.x + PHONE.bezel,
  y: PHONE.y + PHONE.bezel,
  w: PHONE.w - PHONE.bezel * 2,
  h: PHONE.h - PHONE.bezel * 2,
  radius: PHONE.radius - PHONE.bezel,
};

export function defsBlock() {
  return `
    <linearGradient id="bgG" x1="0" y1="0" x2="${CANVAS.w}" y2="${CANVAS.h}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${COLORS.bgStart}"/>
      <stop offset="1" stop-color="${COLORS.bgEnd}"/>
    </linearGradient>
    <linearGradient id="screenG" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${COLORS.screenBgStart}"/>
      <stop offset="1" stop-color="${COLORS.screenBgEnd}"/>
    </linearGradient>
    <linearGradient id="ctaG" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${COLORS.qrGradientStart}"/>
      <stop offset="1" stop-color="${COLORS.qrGradientEnd}"/>
    </linearGradient>
    <filter id="phoneShadow" x="-20%" y="-20%" width="140%" height="140%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="20"/>
      <feOffset dx="0" dy="16" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.4"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="cardShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="10"/>
      <feOffset dx="0" dy="10" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.25"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  `;
}

export function phoneFrame() {
  return `
    <g filter="url(#phoneShadow)">
      <rect x="${PHONE.x}" y="${PHONE.y}" width="${PHONE.w}" height="${PHONE.h}" rx="${PHONE.radius}" ry="${PHONE.radius}" fill="${COLORS.phoneBezel}"/>
      <rect x="${SCREEN.x}" y="${SCREEN.y}" width="${SCREEN.w}" height="${SCREEN.h}" rx="${SCREEN.radius}" ry="${SCREEN.radius}" fill="url(#screenG)"/>
    </g>
    <rect x="${CANVAS.w / 2 - 90}" y="${SCREEN.y + 32}" width="180" height="42" rx="21" ry="21" fill="#0a0a12"/>
  `;
}

export function canvasBackground() {
  return `<rect x="0" y="0" width="${CANVAS.w}" height="${CANVAS.h}" fill="url(#bgG)"/>`;
}

/**
 * The two-line headline, shrunk to fit if the language needs it.
 *
 * 140pt is the series' size and English keeps it. German and Hindi do not, and a
 * headline running off the canvas is worse than a slightly smaller one — so the
 * size is chosen from the longest line rather than fixed. The second baseline
 * follows the size, so the pair keeps its rhythm at any scale.
 */
export function headlineBlock(lines, { y1 = 280, y2 = 460, maxWidth = CANVAS.w - 170 } = {}) {
  const anchorX = CANVAS.w / 2;
  const size = fitFontSize(lines, maxWidth, 140);
  const second = size === 140 ? y2 : y1 + (y2 - y1) * (size / 140);
  return `
    <g text-anchor="middle" fill="#ffffff" font-family="${FONT}">
      <text x="${anchorX}" y="${y1}" font-size="${size}" font-weight="700" letter-spacing="${-3 * size / 140}">${escapeXML(lines[0])}</text>
      ${lines[1] ? `<text x="${anchorX}" y="${second}" font-size="${size}" font-weight="700" letter-spacing="${-3 * size / 140}" opacity="0.92">${escapeXML(lines[1])}</text>` : ""}
    </g>
  `;
}

export function subtitleBlock(text, { y = PHONE.y + PHONE.h + 160, lineHeight = 72, maxWidth = CANVAS.w - 110 } = {}) {
  // Accept a string or an array of lines. Each line is center-aligned, and the
  // whole block shrinks together so the lines stay the same size as each other.
  const lines = Array.isArray(text) ? text : [text];
  const size = fitFontSize(lines, maxWidth, 56);
  const step = lineHeight * (size / 56);
  const tspans = lines.map((line, i) =>
    `<text x="${CANVAS.w / 2}" y="${y + i * step}" font-size="${size}" font-weight="500" opacity="0.95">${escapeXML(line)}</text>`
  ).join("");
  return `
    <g text-anchor="middle" font-family="${FONT}" fill="#ffffff">
      ${tspans}
    </g>
  `;
}

export function svgShell(innerSVG, extraDefs = "") {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${CANVAS.w} ${CANVAS.h}" width="${CANVAS.w}" height="${CANVAS.h}">
  <defs>${defsBlock()}${extraDefs}</defs>
  ${canvasBackground()}
  ${innerSVG}
</svg>
`;
}

export function escapeXML(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}

// MARK: - The app screen, in app points

/**
 * The generator is drawn at real SwiftUI point sizes and scaled into the bezel,
 * so `GeneratorMetrics.regular` can be copied here number for number instead of
 * re-tuned by eye. 392pt across at scale 2 lands the screen at 822pt tall —
 * between an iPhone 15 Pro (852) and the 700pt where the layout switches to its
 * compact metrics, so `.regular` is the right set to mirror.
 */
export const POINTS = { w: 392, h: SCREEN.h / (SCREEN.w / 392) };
export const SCALE = SCREEN.w / POINTS.w;
/** Dynamic Island: content starts below it, as it does in the app. */
export const SAFE_TOP = 59;
export const SAFE_BOTTOM = 34;
/** The app's own horizontal padding, so x=16 means x=16 in both places. */
export const GUTTER = 16;
export const CONTENT_W = POINTS.w - GUTTER * 2;

export function screenDefs(gradientId = "appG") {
  return appScreenDefs({ screen: SCREEN, gradientId, radius: SCREEN.radius });
}

/** Bezel, screen gradient, the app UI drawn in points, then the Island on top. */
export function phoneScreen(body, gradientId = "appG") {
  return `
    <g filter="url(#phoneShadow)">
      <rect x="${PHONE.x}" y="${PHONE.y}" width="${PHONE.w}" height="${PHONE.h}" rx="${PHONE.radius}" ry="${PHONE.radius}" fill="${COLORS.phoneBezel}"/>
      ${appScreen({ screen: SCREEN, points: POINTS, gradientId, body })}
    </g>
    <rect x="${CANVAS.w / 2 - 90}" y="${SCREEN.y + 32}" width="180" height="42" rx="21" ry="21" fill="#0a0a12"/>
  `;
}

/** The Radical Solution footer, at the one height every iPhone scene uses. */
export function signatureBlock(copy, { y = CANVAS.h - 96 } = {}) {
  return signature({ centerX: CANVAS.w / 2, y, copy, size: 38 });
}
