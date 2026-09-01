/**
 * p02-brand-ipad.mjs — the logo and the caption, at the size an iPad gives them.
 *
 * This slot used to hold the launch screen, but `p05-privacy` already shows it,
 * and `LaunchCard` keeps its own fixed sizes: on an iPad it is a small card in a
 * 640pt column with two thirds of the screen under it. The brand family fills
 * the `expanded` layout instead, and carries an argument the iPad set was
 * otherwise missing.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  IPAD_POINTS, IPAD_SAFE_TOP, IPAD_SAFE_BOTTOM, IPAD_GUTTER,
  ipadScreen, ipadShell, ipadHeadline, ipadSubtitle, ipadSignature,
} from "../lib/ipad-frame.mjs";
import { generatorScreen } from "../lib/screens.mjs";
import { fittingMetrics, appMark, INK } from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("brand", LOCALE);

/** The `expanded` preset an upright iPad gets — see GeneratorMetrics.fitting. */
const M = fittingMetrics(IPAD_POINTS.w, IPAD_POINTS.h);

// High correction, because a logo eats modules — the same reason the app raises
// it when a logo is set. The caption band takes 13% of the preview.
const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: M.preview * 0.87,
  roundness: 0.6,
  eyeStyle: "rounded",
  eyeScale: 1.0,
  gradient: { start: "#667EEA", end: "#764BA2", angle: 135 },
  errorCorrection: "H",
  gradientId: "ipadBrandQR",
});

const screen = generatorScreen({
  points: IPAD_POINTS,
  safeTop: IPAD_SAFE_TOP, safeBottom: IPAD_SAFE_BOTTOM, gutter: IPAD_GUTTER,
  copy: L, family: "brand",
  familyOptions: { selection: { hasLogo: true, caption: true, isPro: true } },
  qr, previewSize: M.preview, m: M,
  kind: L.kindURL, content: "radicalsolution.com/radical-qr",
  logo: (lx, ly, side) => appMark(lx, ly, side, INK.railActive),
  caption: L.captionValue,
  showsNavBar: true,
});

writeScene("p02-brand-ipad", LOCALE, ipadShell(`
  ${ipadHeadline(L.headline)}
  ${ipadScreen(screen)}
  ${ipadSubtitle(L.subtitle)}
  ${ipadSignature(L)}
`));
