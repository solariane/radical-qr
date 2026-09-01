/**
 * p05-privacy-ipad.mjs — the promise the app is built around, on iPad.
 * The device shows the launch screen it really opens on, privacy note included.
 */

import { copyFor } from "../lib/copy.mjs";
import { badgeRow, writeScene } from "../lib/poster.mjs";
import {
  IPAD_CANVAS, IPAD_POINTS, IPAD_SAFE_TOP, IPAD_GUTTER,
  ipadScreen, ipadShell, ipadHeadline, ipadSubtitle, ipadSignature,
} from "../lib/ipad-frame.mjs";
import { launchScreen } from "../lib/screens.mjs";
import { fittingMetrics } from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("privacy", LOCALE);
const LAUNCH = copyFor("launch", LOCALE);

/** The `expanded` preset an upright iPad gets — see GeneratorMetrics.fitting. */
const M = fittingMetrics(IPAD_POINTS.w, IPAD_POINTS.h);

const screen = launchScreen({
  points: IPAD_POINTS, safeTop: IPAD_SAFE_TOP, gutter: IPAD_GUTTER,
  copy: LAUNCH, privacyNote: L.note, showsNavBar: true, m: M,
});

writeScene("p05-privacy-ipad", LOCALE, ipadShell(`
  ${ipadHeadline(L.headline)}
  ${badgeRow(L.badges, IPAD_CANVAS.w / 2, 478, { scale: 1.15 })}
  ${ipadScreen(screen)}
  ${ipadSubtitle(L.subtitle)}
  ${ipadSignature(L)}
`));
