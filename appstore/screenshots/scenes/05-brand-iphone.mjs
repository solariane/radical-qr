/**
 * 05-brand-iphone.mjs — the logo and the caption, the two Pro touches that turn
 * a code into a piece of branding.
 *
 * The preview shows both at once, drawn the way the renderer draws them: the
 * logo sits in a cleared quiet zone rather than on top of the modules, and the
 * caption is part of the exported image, not a label in the UI.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  PHONE, headlineBlock, subtitleBlock, svgShell,
  phoneScreen, screenDefs, signatureBlock,
  POINTS, SAFE_TOP, SAFE_BOTTOM, GUTTER, CONTENT_W,
} from "../lib/phone-frame.mjs";
import {
  METRICS as M, header, previewCard, familyRail, actionRow, brandFamily,
  appMark, INK,
} from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("brand", LOCALE);

const headerY = SAFE_TOP + M.sectionGap;
const previewY = headerY + M.headerHeight + M.sectionGap;
const previewH = M.cardPadding * 2 + (M.preview + 12) + M.rowGap + 30;
const railY = previewY + previewH + M.sectionGap;
const panelY = railY + M.railHeight + M.sectionGap;
const actionY = POINTS.h - SAFE_BOTTOM - M.sectionGap - M.actionHeight;

// High correction, because a logo eats modules — the same reason the app raises
// it when a logo is set.
const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  // The caption band takes 13% of the preview, so the code is drawn smaller.
  size: M.preview * 0.87,
  roundness: 0.6,
  eyeStyle: "rounded",
  eyeScale: 1.0,
  gradient: { start: "#667EEA", end: "#764BA2", angle: 135 },
  errorCorrection: "H",
  gradientId: "brandQR",
});

const brand = brandFamily({
  x: GUTTER, y: panelY, width: CONTENT_W, copy: L,
  selection: { hasLogo: true, caption: true, isPro: true },
});

const screen = `
  ${header({ x: GUTTER, y: headerY, width: CONTENT_W })}
  ${previewCard({
    x: GUTTER, y: previewY, width: CONTENT_W,
    qr, previewSize: M.preview,
    kind: L.kindURL, content: "radicalsolution.com/radical-qr",
    logo: (lx, ly, side) => appMark(lx, ly, side, INK.railActive),
    caption: L.captionValue,
  })}
  ${familyRail({ x: GUTTER, y: railY, width: CONTENT_W, active: "brand" })}
  ${brand.svg}
  ${actionRow({ x: GUTTER, y: actionY, width: CONTENT_W, label: L.save })}
`;

const inner = `
  ${headlineBlock(L.headline)}
  ${phoneScreen(screen)}
  ${subtitleBlock(L.subtitle, { y: PHONE.y + PHONE.h + 150 })}
  ${signatureBlock(L)}
`;

writeScene("05-brand-iphone-6.9", LOCALE, svgShell(inner, screenDefs()));
