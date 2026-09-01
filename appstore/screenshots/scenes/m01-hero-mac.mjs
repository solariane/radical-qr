/**
 * m01-hero-mac.mjs — the Mac listing's first shot.
 *
 * macOS is the one platform where `ContentView` really does split, so this is
 * the only frame that draws a sidebar. The detail pane is the same generator as
 * everywhere else — same `screens.mjs`, same metrics — because it is the same
 * view.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { badgeRow, writeScene } from "../lib/poster.mjs";
import {
  MAC_CANVAS, MAC_POINTS, MAC_DETAIL, MAC_SIDEBAR_W, MAC_GUTTER,
  macWindow, macSidebar, macShell, macHeadline, macSubtitle, macSignature,
} from "../lib/mac-frame.mjs";
import { generatorScreen } from "../lib/screens.mjs";
import { fittingMetrics } from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("hero", LOCALE);

/**
 * The detail pane is wide and short, so `GeneratorMetrics.fitting` returns the
 * `split` preset: the settings sit beside the code rather than under it.
 */
const M = fittingMetrics(MAC_DETAIL.w, MAC_POINTS.h);

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: M.preview, roundness: 0.6, eyeStyle: "leaf", eyeScale: 0.9,
  gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 },
  errorCorrection: "M", gradientId: "macHeroQR",
});

const body = `
  ${macSidebar({ copy: L, active: "generator" })}
  ${generatorScreen({
    points: { w: MAC_DETAIL.w, h: MAC_POINTS.h },
    safeTop: 10, safeBottom: 10, gutter: MAC_GUTTER, originX: MAC_SIDEBAR_W,
    copy: L, family: "shape",
    familyOptions: { selection: { roundness: 0.6, eyeStyle: "leaf", eyeScale: 0.9 } },
    qr, previewSize: M.preview, m: M,
    kind: L.kindURL, content: "radicalsolution.com/radical-qr",
  })}
`;

writeScene("m01-hero-mac", LOCALE, macShell(`
  ${macHeadline(L.headline)}
  ${macWindow(body)}
  ${macSubtitle(L.subtitle)}
  ${macSignature(L)}
`));
