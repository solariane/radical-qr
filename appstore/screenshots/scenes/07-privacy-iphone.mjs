/**
 * 07-privacy-iphone.mjs — the reason to pick this one over the free web tools.
 *
 * No mockup trick here: the phone shows the same launch screen the app opens on,
 * privacy note and all, and the poster does the arguing. The claims are the ones
 * the app can actually keep — no account, no analytics SDK, no server — which is
 * why they are the same four lines as the Privacy section of the listing.
 */

import { copyFor } from "../lib/copy.mjs";
import { badgeRow, writeScene } from "../lib/poster.mjs";
import {
  CANVAS, PHONE, headlineBlock, subtitleBlock, svgShell,
  phoneScreen, screenDefs, signatureBlock,
  SAFE_TOP, GUTTER, CONTENT_W,
} from "../lib/phone-frame.mjs";
import {
  METRICS as M, header, launchCard, launchCardMetrics, inlineNote,
} from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("privacy", LOCALE);
const LAUNCH = copyFor("launch", LOCALE);

const headerY = SAFE_TOP + M.sectionGap;
const cardY = headerY + M.headerHeight + M.sectionGap;
const noteY = cardY + launchCardMetrics(LAUNCH, CONTENT_W).height + M.sectionGap + 12;

const screen = `
  ${header({ x: GUTTER, y: headerY, width: CONTENT_W })}
  ${launchCard({ x: GUTTER, y: cardY, width: CONTENT_W, copy: LAUNCH })}
  ${inlineNote({ centerX: GUTTER + CONTENT_W / 2, y: noteY, label: L.note })}
`;

const inner = `
  ${headlineBlock(L.headline)}
  ${badgeRow(L.badges, CANVAS.w / 2, 578)}
  ${phoneScreen(screen)}
  ${subtitleBlock(L.subtitle, { y: PHONE.y + PHONE.h + 150 })}
  ${signatureBlock(L)}
`;

writeScene("07-privacy-iphone-6.9", LOCALE, svgShell(inner, screenDefs()));
