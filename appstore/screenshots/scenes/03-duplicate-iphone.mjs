/**
 * 03-duplicate-iphone.mjs — the headline feature of 2.0, and the one the old
 * screenshots never showed.
 *
 * It draws `CodeScannerSheet` as it is: black, the camera, a close button at the
 * top left and the hint capsule above the home indicator. Nothing invented — no
 * reticle, because the app has none. What the camera is looking at is a printed
 * code on a card, plain black, so the poster's own before/after does the
 * explaining: this is somebody else's code, about to become yours.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  CANVAS, PHONE, headlineBlock, subtitleBlock, svgShell,
  phoneScreen, screenDefs, signatureBlock,
  SCREEN, SCALE, POINTS, SAFE_TOP, SAFE_BOTTOM, GUTTER,
} from "../lib/phone-frame.mjs";
import { text, FONT, INK, esc } from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("duplicate", LOCALE);

const CONTENT = "https://radicalsolution.com/radical-qr";

// --- What the camera sees --------------------------------------------------

/** The printed code: plain black, square modules — someone else's poster. */
const printed = renderQR({
  content: CONTENT,
  size: 210,
  roundness: 0,
  eyeStyle: "square",
  color: "#111111",
  errorCorrection: "M",
});

const cardW = 250;
const cardH = 296;
const cardX = (POINTS.w - cardW) / 2;
const cardY = 246;

const scannerScreen = `
  <rect x="0" y="0" width="${POINTS.w}" height="${POINTS.h}" fill="#08080C"/>

  <!-- The camera feed: a lit wall, and the printed code on it. -->
  <defs>
    <radialGradient id="camLight" cx="0.5" cy="0.42" r="0.72">
      <stop offset="0" stop-color="#4A4358"/>
      <stop offset="1" stop-color="#14131A"/>
    </radialGradient>
  </defs>
  <rect x="0" y="0" width="${POINTS.w}" height="${POINTS.h}" fill="url(#camLight)"/>

  <g transform="rotate(-3 ${POINTS.w / 2} ${cardY + cardH / 2})">
    <rect x="${cardX + 4}" y="${cardY + 8}" width="${cardW}" height="${cardH}" rx="8" fill="#000000" opacity="0.35"/>
    <rect x="${cardX}" y="${cardY}" width="${cardW}" height="${cardH}" rx="8" fill="#F4F2EE"/>
    <g transform="translate(${cardX + (cardW - 210) / 2} ${cardY + 24})">${printed}</g>
    <text x="${cardX + cardW / 2}" y="${cardY + 268}" text-anchor="middle" font-family="${FONT}"
      font-size="14" font-weight="600" fill="#111111" letter-spacing="0.4">${esc(L.readValue)}</text>
  </g>

  <!-- Sheet chrome -->
  <circle cx="${GUTTER + 24}" cy="${SAFE_TOP + 12 + 20}" r="20" fill="#000000" fill-opacity="0.45"/>
  <g transform="translate(${GUTTER + 24} ${SAFE_TOP + 12 + 20}) rotate(45)">
    <path d="M-7 0 H7 M0 -7 V7" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round"/>
  </g>

  ${(() => {
    const hint = L.scannerHint;
    const w = hint.length * 13 * 0.5 + 48;
    const x = (POINTS.w - w) / 2;
    const y = POINTS.h - SAFE_BOTTOM - 40 - 40;
    return `<rect x="${x}" y="${y}" width="${w}" height="40" rx="20" fill="#000000" fill-opacity="0.5"/>
      ${text(POINTS.w / 2, y + 25, hint, { size: 13, fill: "#ffffff", anchor: "middle" })}`;
  })()}
`;

// --- Poster: what came out of it -------------------------------------------

/** The same payload, restyled — the point of the feature, in one object. */
const restyled = renderQR({
  content: CONTENT,
  size: 200,
  roundness: 0.6,
  eyeStyle: "leaf",
  eyeScale: 0.9,
  gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 },
  background: null,
  errorCorrection: "M",
  gradientId: "dupRestyled",
});

/**
 * The result, as a card leaning on the phone's bottom corner: the scanner alone
 * shows a code being read, not a code being *remade*, which is the feature.
 * It sits clear of the hint capsule — that line has to stay readable.
 */
function outcome() {
  const size = 200;
  const x = CANVAS.w - size - 60;
  // Just below the printed card and clear of the hint capsule: the eye runs
  // down the screen from the code being read to the code that came out.
  const y = SCREEN.y + (cardY + cardH) * SCALE + 34;
  return `<g filter="url(#cardShadow)">
    <rect x="${x - 26}" y="${y - 26}" width="${size + 52}" height="${size + 92}" rx="28" fill="#ffffff"/>
    <g transform="translate(${x} ${y})">${restyled}</g>
    <text x="${x + size / 2}" y="${y + size + 42}" text-anchor="middle" font-family="${FONT}"
      font-size="30" font-weight="600" fill="${INK.railActive}" letter-spacing="1">${esc(L.after.toUpperCase())}</text>
  </g>`;
}

const inner = `
  ${headlineBlock(L.headline)}
  ${phoneScreen(scannerScreen)}
  ${outcome()}
  ${subtitleBlock(L.subtitle, { y: PHONE.y + PHONE.h + 150 })}
  ${signatureBlock(L)}
`;

writeScene("03-duplicate-iphone-6.9", LOCALE, svgShell(inner, screenDefs()));
