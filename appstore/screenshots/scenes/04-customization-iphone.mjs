/**
 * 04-customization-iphone.mjs — the argument 2.0 was built on.
 *
 * The old screenshot for this slot drew rows of translated capsules — "Sharp",
 * "Rounded", "Circular" — which is exactly what the release removed. This one
 * blows the tiles up above the phone so the claim is visible at listing size:
 * every option is its own result, drawn. The phone below shows a different
 * family open (colour), which is the other half of the story — one family at a
 * time is what keeps the whole screen scroll-free.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  CANVAS, PHONE, headlineBlock, subtitleBlock, svgShell,
  phoneScreen, screenDefs, signatureBlock,
  POINTS, SAFE_TOP, SAFE_BOTTOM, GUTTER, CONTENT_W,
} from "../lib/phone-frame.mjs";
import {
  METRICS as M, header, previewCard, familyRail, actionRow, colorFamily,
  settingTile, moduleShapeGlyph, eyeShapeGlyph,
} from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("customization", LOCALE);

// --- The tiles, at poster scale --------------------------------------------

/**
 * Eight real tiles, drawn by the same code the phone below uses — four module
 * corner steps and four eye shapes. Blown up to 96pt they survive the App Store
 * thumbnail, which a 48pt tile inside a phone mockup does not.
 */
function tileShowcase(cy) {
  const side = 96;
  const gap = 18;
  const groupGap = 46;
  const modules = [0, 0.3, 0.6, 1.0];
  const eyes = ["square", "rounded", "dot", "leaf"];
  const total = side * 8 + gap * 6 + groupGap;
  let x = CANVAS.w / 2 - total / 2;
  const y = cy - side / 2;

  const moduleTiles = modules.map((step, i) => {
    const tile = settingTile({
      x: x + (side + gap) * i, y, w: side, h: side,
      selected: step === 0.6,
      content: (gx, gy, s) => moduleShapeGlyph(gx, gy, s, step),
    });
    return tile;
  }).join("");

  x += (side + gap) * 4 - gap + groupGap;

  const eyeTiles = eyes.map((style, i) => settingTile({
    x: x + (side + gap) * i, y, w: side, h: side,
    selected: style === "leaf",
    content: (gx, gy, s) => eyeShapeGlyph(gx, gy, s, style),
  })).join("");

  return `<g>${moduleTiles}${eyeTiles}</g>`;
}

// --- The phone -------------------------------------------------------------

const headerY = SAFE_TOP + M.sectionGap;
const previewY = headerY + M.headerHeight + M.sectionGap;
const previewH = M.cardPadding * 2 + (M.preview + 12) + M.rowGap + 30;
const railY = previewY + previewH + M.sectionGap;
const panelY = railY + M.railHeight + M.sectionGap;
const actionY = POINTS.h - SAFE_BOTTOM - M.sectionGap - M.actionHeight;

const qr = renderQR({
  content: "https://radicalsolution.com/radical-qr",
  size: M.preview,
  roundness: 1.0,
  eyeStyle: "dot",
  eyeScale: 1.0,
  gradient: { start: "#3B82F6", end: "#38C8D5", angle: 135 },
  errorCorrection: "M",
  gradientId: "customQR",
});

const colors = colorFamily({
  x: GUTTER, y: panelY, width: CONTENT_W, copy: L,
  selection: { gradient: 1, background: "white" },
});

const screen = `
  ${header({ x: GUTTER, y: headerY, width: CONTENT_W })}
  ${previewCard({
    x: GUTTER, y: previewY, width: CONTENT_W,
    qr, previewSize: M.preview,
    kind: L.kindURL, content: "radicalsolution.com/radical-qr",
  })}
  ${familyRail({ x: GUTTER, y: railY, width: CONTENT_W, active: "color" })}
  ${colors.svg}
  ${actionRow({ x: GUTTER, y: actionY, width: CONTENT_W, label: L.save })}
`;

const inner = `
  ${headlineBlock(L.headline)}
  ${tileShowcase(578)}
  ${phoneScreen(screen)}
  ${subtitleBlock(L.subtitle, { y: PHONE.y + PHONE.h + 150 })}
  ${signatureBlock(L)}
`;

writeScene("04-customization-iphone-6.9", LOCALE, svgShell(inner, screenDefs()));
