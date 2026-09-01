/**
 * p04-duplicate-ipad.mjs — 2.0's headline feature, on iPad.
 *
 * Same `CodeScannerSheet` as the phone: black, camera, close button, hint
 * capsule. The card the camera is looking at is a printed code in plain black,
 * and the poster shows what came out of it.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  IPAD_CANVAS, IPAD_SCREEN, IPAD_SCALE, IPAD_POINTS,
  IPAD_SAFE_TOP, IPAD_SAFE_BOTTOM, IPAD_GUTTER,
  ipadScreen, ipadShell, ipadHeadline, ipadSubtitle, ipadSignature, ipadEscape, IPAD_FONT,
} from "../lib/ipad-frame.mjs";
import { text, INK } from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("duplicate", LOCALE);
const CONTENT = "https://radicalsolution.com/radical-qr";

const printed = renderQR({
  content: CONTENT, size: 300, roundness: 0, eyeStyle: "square",
  color: "#111111", errorCorrection: "M",
});

const cardW = 356;
const cardH = 424;
const cardX = (IPAD_POINTS.w - cardW) / 2;
const cardY = 300;

const scannerScreen = `
  <defs>
    <radialGradient id="padCamLight" cx="0.5" cy="0.42" r="0.72">
      <stop offset="0" stop-color="#4A4358"/>
      <stop offset="1" stop-color="#14131A"/>
    </radialGradient>
  </defs>
  <rect x="0" y="0" width="${IPAD_POINTS.w}" height="${IPAD_POINTS.h}" fill="url(#padCamLight)"/>

  <g transform="rotate(-3 ${IPAD_POINTS.w / 2} ${cardY + cardH / 2})">
    <rect x="${cardX + 6}" y="${cardY + 10}" width="${cardW}" height="${cardH}" rx="10" fill="#000000" opacity="0.35"/>
    <rect x="${cardX}" y="${cardY}" width="${cardW}" height="${cardH}" rx="10" fill="#F4F2EE"/>
    <g transform="translate(${cardX + (cardW - 300) / 2} ${cardY + 34})">${printed}</g>
    <text x="${cardX + cardW / 2}" y="${cardY + 384}" text-anchor="middle" font-family="${IPAD_FONT}"
      font-size="19" font-weight="600" fill="#111111" letter-spacing="0.4">${ipadEscape(L.readValue)}</text>
  </g>

  <circle cx="${IPAD_GUTTER + 28}" cy="${IPAD_SAFE_TOP + 12 + 22}" r="22" fill="#000000" fill-opacity="0.45"/>
  <g transform="translate(${IPAD_GUTTER + 28} ${IPAD_SAFE_TOP + 12 + 22}) rotate(45)">
    <path d="M-8 0 H8 M0 -8 V8" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round"/>
  </g>

  ${(() => {
    const w = L.scannerHint.length * 15 * 0.5 + 56;
    const x = (IPAD_POINTS.w - w) / 2;
    const y = IPAD_POINTS.h - IPAD_SAFE_BOTTOM - 40 - 44;
    return `<rect x="${x}" y="${y}" width="${w}" height="44" rx="22" fill="#000000" fill-opacity="0.5"/>
      ${text(IPAD_POINTS.w / 2, y + 28, L.scannerHint, { size: 15, fill: "#ffffff", anchor: "middle" })}`;
  })()}
`;

const restyled = renderQR({
  content: CONTENT, size: 280, roundness: 0.6, eyeStyle: "leaf", eyeScale: 0.9,
  gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 },
  errorCorrection: "M", gradientId: "padDupRestyled",
});

/** Below the printed card, clear of the hint: read here, remade there. */
function outcome() {
  const size = 280;
  const x = IPAD_CANVAS.w - size - 110;
  const y = IPAD_SCREEN.y + (cardY + cardH) * IPAD_SCALE + 40;
  return `<g filter="url(#ipadCardShadow)">
    <rect x="${x - 34}" y="${y - 34}" width="${size + 68}" height="${size + 118}" rx="34" fill="#ffffff"/>
    <g transform="translate(${x} ${y})">${restyled}</g>
    <text x="${x + size / 2}" y="${y + size + 56}" text-anchor="middle" font-family="${IPAD_FONT}"
      font-size="36" font-weight="600" fill="${INK.railActive}" letter-spacing="1">${ipadEscape(L.after.toUpperCase())}</text>
  </g>`;
}

writeScene("p04-duplicate-ipad", LOCALE, ipadShell(`
  ${ipadHeadline(L.headline)}
  ${ipadScreen(scannerScreen)}
  ${outcome()}
  ${ipadSubtitle(L.subtitle)}
  ${ipadSignature(L)}
`));
