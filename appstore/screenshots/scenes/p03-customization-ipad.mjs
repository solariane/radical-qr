/**
 * p03-customization-ipad.mjs — settings that draw themselves.
 *
 * The scene this replaces still showed the four translated capsules 2.0 deleted
 * — "Sharp", "Slight", "Rounded", "Circular" — which contradicted the release
 * notes it sat next to. The tiles are now blown up above the device so the claim
 * survives the App Store's thumbnail strip.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  IPAD, IPAD_CANVAS, IPAD_POINTS, IPAD_SAFE_TOP, IPAD_SAFE_BOTTOM, IPAD_GUTTER,
  ipadScreen, ipadShell, ipadHeadline, ipadHeadlineBottom, ipadSubtitle, ipadSignature,
} from "../lib/ipad-frame.mjs";
import { generatorScreen } from "../lib/screens.mjs";
import {
  fittingMetrics, settingTile, moduleShapeGlyph, eyeShapeGlyph,
} from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("customization", LOCALE);

/**
 * What `GeneratorMetrics.fitting` returns for an upright iPad: the `expanded`
 * preset, with the preview grown into the height a 13" screen has spare.
 */
const M = fittingMetrics(IPAD_POINTS.w, IPAD_POINTS.h);

/**
 * This scene is the only one that puts a full row between the headline and the
 * device, and the default headline leaves it 98pt — less than the row is tall.
 * So the headline sits higher here, and the tiles take what that frees rather
 * than a fixed size: a translation that shrinks the type gives them more, and
 * they can never grow back into the text or the bezel.
 */
const HEADLINE = { y1: 195, y2: 325 };
const GAP_ABOVE = 28;
const GAP_BELOW = 26;
const HEADLINE_BOTTOM = ipadHeadlineBottom(L.headline, HEADLINE);
const TILE_SIDE = Math.min(116, IPAD.y - HEADLINE_BOTTOM - GAP_ABOVE - GAP_BELOW);

/** The same tiles the device below draws, at a size the listing can read. */
function tileShowcase(cy, side) {
  const gap = 22;
  const groupGap = 58;
  const total = side * 8 + gap * 6 + groupGap;
  let x = IPAD_CANVAS.w / 2 - total / 2;
  const y = cy - side / 2;

  const modules = [0, 0.3, 0.6, 1.0].map((step, i) => settingTile({
    x: x + (side + gap) * i, y, w: side, h: side, selected: step === 0.6,
    content: (gx, gy, s) => moduleShapeGlyph(gx, gy, s, step),
  })).join("");

  x += (side + gap) * 4 - gap + groupGap;

  const eyes = ["square", "rounded", "dot", "leaf"].map((style, i) => settingTile({
    x: x + (side + gap) * i, y, w: side, h: side, selected: style === "leaf",
    content: (gx, gy, s) => eyeShapeGlyph(gx, gy, s, style),
  })).join("");

  return `<g>${modules}${eyes}</g>`;
}

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: M.preview, roundness: 1.0, eyeStyle: "dot", eyeScale: 1.0,
  gradient: { start: "#3B82F6", end: "#38C8D5", angle: 135 },
  errorCorrection: "M", gradientId: "ipadCustomQR",
});

const screen = generatorScreen({
  points: IPAD_POINTS,
  safeTop: IPAD_SAFE_TOP, safeBottom: IPAD_SAFE_BOTTOM, gutter: IPAD_GUTTER,
  copy: L, family: "color",
  familyOptions: { selection: { gradient: 1, background: "white" } },
  qr, previewSize: M.preview, m: M,
  kind: L.kindURL, content: "radicalsolution.com/radical-qr",
  showsNavBar: true,
});

writeScene("p03-customization-ipad", LOCALE, ipadShell(`
  ${ipadHeadline(L.headline, HEADLINE)}
  ${tileShowcase(HEADLINE_BOTTOM + GAP_ABOVE + TILE_SIDE / 2, TILE_SIDE)}
  ${ipadScreen(screen)}
  ${ipadSubtitle(L.subtitle)}
  ${ipadSignature(L)}
`));
