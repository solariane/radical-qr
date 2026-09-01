/**
 * p01-hero-ipad.mjs — the listing's first iPad shot.
 *
 * Same screen as the iPhone hero, because that is literally what the app shows:
 * `ContentView` wraps `GeneratorView` in a `NavigationStack` on every iOS
 * device, so an iPad gets a wider generator, not a different one. The preview
 * stays at `GeneratorMetrics.preview` — the code does not grow with the screen,
 * and a screenshot that pretended otherwise would be a lie the app can't keep.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { badgeRow, writeScene } from "../lib/poster.mjs";
import {
  IPAD_CANVAS, IPAD_POINTS, IPAD_SAFE_TOP, IPAD_SAFE_BOTTOM, IPAD_GUTTER,
  ipadScreen, ipadShell, ipadHeadline, ipadSubtitle, ipadSignature,
} from "../lib/ipad-frame.mjs";
import { generatorScreen } from "../lib/screens.mjs";
import { fittingMetrics } from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("hero", LOCALE);

/**
 * What `GeneratorMetrics.fitting` returns for an upright iPad: the `expanded`
 * preset, with the preview grown into the height a 13" screen has spare.
 */
const M = fittingMetrics(IPAD_POINTS.w, IPAD_POINTS.h);

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: M.preview,
  roundness: 0.6,
  eyeStyle: "leaf",
  eyeScale: 0.9,
  gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 },
  errorCorrection: "M",
  gradientId: "ipadHeroQR",
});

const screen = generatorScreen({
  points: IPAD_POINTS,
  safeTop: IPAD_SAFE_TOP, safeBottom: IPAD_SAFE_BOTTOM, gutter: IPAD_GUTTER,
  copy: L, family: "shape",
  familyOptions: { selection: { roundness: 0.6, eyeStyle: "leaf", eyeScale: 0.9 } },
  qr, previewSize: M.preview, m: M,
  kind: L.kindURL, content: "radicalsolution.com/radical-qr",
  showsNavBar: true,
});

writeScene("p01-hero-ipad", LOCALE, ipadShell(`
  ${ipadHeadline(L.headline)}
  ${badgeRow(L.badges, IPAD_CANVAS.w / 2, 478, { scale: 1.15 })}
  ${ipadScreen(screen)}
  ${ipadSubtitle(L.subtitle)}
  ${ipadSignature(L)}
`));
