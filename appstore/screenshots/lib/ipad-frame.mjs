/**
 * ipad-frame.mjs — iPad Pro 13" portrait poster (2064 × 2752).
 *
 * This used to draw a `NavigationSplitView`: sidebar on the left, generator on
 * the right. The app has never done that on iPad — `ContentView` only splits on
 * macOS, and iPad gets the same `NavigationStack` as iPhone. So the frame now
 * draws one full-width screen, and the scenes share `screens.mjs` with the phone
 * rather than maintaining a second, invented layout.
 *
 * The screen is drawn in app points and scaled, as on iPhone. 1024pt across at
 * ~1.39 lands the height at 1385pt — an iPad Pro 13" is 1024 × 1366, so the
 * generator's `.regular` metrics are the right ones to mirror here too.
 */

import { appScreen, appScreenDefs, fitFontSize } from "./app-ui.mjs";
import { signature } from "./signature.mjs";

export const IPAD_CANVAS = { w: 2064, h: 2752 };

export const IPAD_COLORS = {
  bgStart: "#667eea",
  bgEnd: "#764ba2",
  deviceBezel: "#0f0f18",
  screenBgStart: "#7b8fef",
  screenBgEnd: "#8a5fb8",
  qrGradientStart: "#4D33D9",
  qrGradientEnd: "#8C3BBF",
};

export const IPAD_FONT = `-apple-system, 'SF Pro Display', 'Helvetica Neue', Helvetica, Arial, sans-serif`;

/**
 * Smaller than the canvas allows, on purpose: the poster needs a headline, a
 * badge row, two subtitle lines and the signature, and a 2000pt-tall device left
 * the last two sitting on the bezel. 3:4, so the proportions stay an iPad's.
 */
export const IPAD = {
  w: 1380,
  h: 1840,
  x: (IPAD_CANVAS.w - 1380) / 2,
  y: 520,
  bezel: 32,
  radius: 92,
};

export const IPAD_SCREEN = {
  x: IPAD.x + IPAD.bezel,
  y: IPAD.y + IPAD.bezel,
  w: IPAD.w - IPAD.bezel * 2,
  h: IPAD.h - IPAD.bezel * 2,
  radius: IPAD.radius - IPAD.bezel,
};

export const IPAD_POINTS = { w: 1024, h: IPAD_SCREEN.h / (IPAD_SCREEN.w / 1024) };
export const IPAD_SCALE = IPAD_SCREEN.w / IPAD_POINTS.w;
/** iPad has no notch: the status bar is 24pt, and the home indicator 20pt. */
export const IPAD_SAFE_TOP = 24;
export const IPAD_SAFE_BOTTOM = 20;
export const IPAD_GUTTER = 16;

export function ipadDefs() {
  return `
    <linearGradient id="ipadBgG" x1="0" y1="0" x2="${IPAD_CANVAS.w}" y2="${IPAD_CANVAS.h}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${IPAD_COLORS.bgStart}"/>
      <stop offset="1" stop-color="${IPAD_COLORS.bgEnd}"/>
    </linearGradient>
    <filter id="ipadDeviceShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="28"/>
      <feOffset dx="0" dy="20" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.4"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="ipadCardShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="14"/>
      <feOffset dx="0" dy="10" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.22"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    ${appScreenDefs({ screen: IPAD_SCREEN, gradientId: "ipadAppG", radius: IPAD_SCREEN.radius })}
  `;
}

export function ipadBackground() {
  return `<rect x="0" y="0" width="${IPAD_CANVAS.w}" height="${IPAD_CANVAS.h}" fill="url(#ipadBgG)"/>`;
}

export function ipadScreen(body) {
  return `
    <g filter="url(#ipadDeviceShadow)">
      <rect x="${IPAD.x}" y="${IPAD.y}" width="${IPAD.w}" height="${IPAD.h}"
        rx="${IPAD.radius}" ry="${IPAD.radius}" fill="${IPAD_COLORS.deviceBezel}"/>
      ${appScreen({ screen: IPAD_SCREEN, points: IPAD_POINTS, gradientId: "ipadAppG", body })}
    </g>
  `;
}

/**
 * Where the headline actually sits, so a scene can place something under it.
 *
 * A long translation shrinks the type, which pulls the second line up — the
 * clearance a scene needs is therefore not a constant, and hard-coding one is
 * what put the tile row through the middle of "Not settings you read."
 */
function ipadHeadlineLayout(lines, { y1 = 230, y2 = 390, maxWidth = IPAD_CANVAS.w - 220 } = {}) {
  const size = fitFontSize(lines, maxWidth, 132);
  const second = size === 132 ? y2 : y1 + (y2 - y1) * (size / 132);
  // 0.24em covers the descender of a g or a y, which is what collides first.
  return { size, y1, second, bottom: (lines[1] ? second : y1) + size * 0.24 };
}

/** Lowest ink of the headline, descenders included. */
export function ipadHeadlineBottom(lines, opts = {}) {
  return ipadHeadlineLayout(lines, opts).bottom;
}

export function ipadHeadline(lines, opts = {}) {
  const { size, y1, second } = ipadHeadlineLayout(lines, opts);
  return `
    <g text-anchor="middle" fill="#ffffff" font-family="${IPAD_FONT}">
      <text x="${IPAD_CANVAS.w / 2}" y="${y1}" font-size="${size}" font-weight="700" letter-spacing="${-3 * size / 132}">${ipadEscape(lines[0])}</text>
      ${lines[1] ? `<text x="${IPAD_CANVAS.w / 2}" y="${second}" font-size="${size}" font-weight="700" letter-spacing="${-3 * size / 132}" opacity="0.92">${ipadEscape(lines[1])}</text>` : ""}
    </g>
  `;
}

export function ipadSubtitle(text, { y = IPAD.y + IPAD.h + 140, lineHeight = 68, maxWidth = IPAD_CANVAS.w - 180 } = {}) {
  const lines = Array.isArray(text) ? text : [text];
  const size = fitFontSize(lines, maxWidth, 54);
  const step = lineHeight * (size / 54);
  return `
    <g text-anchor="middle" font-family="${IPAD_FONT}" fill="#ffffff">
      ${lines.map((line, i) =>
        `<text x="${IPAD_CANVAS.w / 2}" y="${y + i * step}" font-size="${size}" font-weight="500" opacity="0.95">${ipadEscape(line)}</text>`
      ).join("")}
    </g>
  `;
}

export function ipadSignature(copy, { y = IPAD_CANVAS.h - 92 } = {}) {
  return signature({ centerX: IPAD_CANVAS.w / 2, y, copy, size: 40 });
}

export function ipadShell(innerSVG) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${IPAD_CANVAS.w} ${IPAD_CANVAS.h}" width="${IPAD_CANVAS.w}" height="${IPAD_CANVAS.h}">
  <defs>${ipadDefs()}</defs>
  ${ipadBackground()}
  ${innerSVG}
</svg>
`;
}

export function ipadEscape(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
