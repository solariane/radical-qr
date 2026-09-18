/**
 * 02b-paste-iphone.mjs — the headline of 2.1: text written for people becomes
 * the right code.
 *
 * Above the phone, the text as someone would paste it. On the screen,
 * `EventEditorCard` as the app opens it for that text — title, start, end,
 * all-day off, the location filled in, the link folded behind "+ URL" — then the
 * preview card with the calendar code, and the pinned save row.
 *
 * The example is not invented: en-US and fr-FR were run through EventDetector
 * and this is what it returns (translate-copy.mjs never translates it). Every
 * interface label comes from Localizable.xcstrings through app-strings.mjs, and
 * dates are formatted with the locale's own calendar conventions.
 *
 * Named 02b so it sorts third, after the launch screen: the first three
 * screenshots are the ones the App Store shows in search results.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor, isRTL } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import { appString, intlLocale } from "../lib/app-strings.mjs";
import { symbol } from "../lib/symbols.mjs";
import {
  CANVAS, PHONE, headlineBlock, subtitleBlock, svgShell,
  phoneScreen, screenDefs, signatureBlock,
  POINTS, SAFE_TOP, SAFE_BOTTOM, GUTTER, CONTENT_W, FONT as POSTER_FONT, escapeXML,
} from "../lib/phone-frame.mjs";
import {
  METRICS as M, NAV_HEIGHT, INK, header, previewCard, actionRow, text, estimateTextWidth, fitFontSize,
} from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("paste", LOCALE);
const S = (key) => appString(key, LOCALE);

// --- The event the detector returns for L.pastedExample -------------------

/** Saturday 19 September 2026, 20:00–21:00 — what "samedi 20h" meant that week. */
const start = new Date(2026, 8, 19, 20, 0);
const end = new Date(2026, 8, 19, 21, 0);
const lang = intlLocale(LOCALE);
// In a right-to-left locale a date is a left-to-right run inside RTL text; without
// the marks the renderer reorders its pieces ("192026/09/").
// Intl's Arabic dates already carry right-to-left marks between their parts;
// they go, so the whole date is one left-to-right run.
const ltr = (s) => (isRTL(LOCALE) ? `\u200E${s.replace(/[\u200F\u061C]/g, "")}\u200E` : s);
const day = ltr(new Intl.DateTimeFormat(lang, { dateStyle: "medium" }).format(start));
const time = (d) => ltr(new Intl.DateTimeFormat(lang, { timeStyle: "short" }).format(d));

const ical = [
  "BEGIN:VEVENT",
  `SUMMARY:${L.exampleTitle}`,
  "DTSTART:20260919T180000Z",
  "DTEND:20260919T190000Z",
  `LOCATION:${L.exampleLocation.replaceAll(",", "\\,")}`,
  "END:VEVENT",
].join("\r\n");

// --- EventEditorCard, in points ---------------------------------------------

const FIELD = "#EEEEF1";
const FIELD_H = 42;
const DATE_ROW_H = 36;
const RADIUS_FIELD = 12;

const rect = (x, y, w, h, r, fill) =>
  `<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${r}" ry="${r}" fill="${fill}"/>`;

/** A grey field with its value, as `editorFieldBackground()` draws it. */
function field(x, y, w, value, { weight = 400 } = {}) {
  return `${rect(x, y, w, FIELD_H, RADIUS_FIELD, FIELD)}
    ${text(x + 12, y + 27, value, { size: 16, weight, fill: INK.label })}`;
}

/** A `DatePicker` row in `.compact` style: label left, date and time capsules right. */
function dateRow(x, y, w, label, values) {
  let right = x + w;
  const pills = [...values].reverse().map((value) => {
    const pw = estimateTextWidth(value, 15) + 22;
    right -= pw;
    const svg = `${rect(right, y + 2, pw, DATE_ROW_H - 4, 8, FIELD)}
      ${text(right + pw / 2, y + 23, value, { size: 15, fill: INK.label, anchor: "middle" })}`;
    right -= 6;
    return svg;
  }).join("");
  return `${text(x, y + 23, label, { size: 15, fill: INK.label })}${pills}`;
}

function editorCard(x, y, w) {
  const pad = M.cardPadding;
  const innerX = x + pad;
  const innerW = w - pad * 2;
  let cy = y + pad;
  const parts = [];

  // Header: type, "Keep as text", clear.
  const keep = S("editor.keepAsText");
  parts.push(symbol("calendar", innerX + 9, cy + 11, 18, INK.accent, "medium"));
  parts.push(text(innerX + 26, cy + 17, S("dataType.icalendar"), { size: 17, weight: 600, fill: INK.label }));
  parts.push(symbol("xmark.circle.fill", innerX + innerW - 11, cy + 11, 22, "#AEAEB2"));
  parts.push(text(innerX + innerW - 30, cy + 16.5, keep, { size: 15, fill: INK.accent, anchor: "end" }));
  cy += 22 + M.rowGap;

  parts.push(field(innerX, cy, innerW, L.exampleTitle, { weight: 500 }));
  cy += FIELD_H + M.rowGap;

  parts.push(dateRow(innerX, cy, innerW, S("event.starts"), [day, time(start)]));
  cy += DATE_ROW_H + 6;
  parts.push(dateRow(innerX, cy, innerW, S("event.ends"), [day, time(end)]));
  cy += DATE_ROW_H + 6;

  // All-day, off.
  parts.push(text(innerX, cy + 22, S("event.allDay"), { size: 15, fill: INK.label }));
  parts.push(rect(innerX + innerW - 51, cy + 2, 51, 31, 15.5, "#E3E3E8"));
  parts.push(`<circle cx="${innerX + innerW - 51 + 15.5}" cy="${cy + 17.5}" r="13.5" fill="#ffffff"/>`);
  cy += 34 + M.rowGap;

  parts.push(field(innerX, cy, innerW, L.exampleLocation));
  cy += FIELD_H + M.rowGap;

  // The link, folded: "+ URL".
  const urlLabel = S("event.url.placeholder");
  const capW = estimateTextWidth(urlLabel, 15) + 46;
  parts.push(rect(innerX, cy, capW, 32, 16, "#EFEFF4"));
  parts.push(symbol("plus", innerX + 17, cy + 16, 13, INK.accent, "semibold"));
  parts.push(text(innerX + 30, cy + 21, urlLabel, { size: 15, fill: INK.accent }));
  cy += 32 + pad;

  return {
    height: cy - y,
    svg: `<g>${rect(x, y, w, cy - y, 26, "#ffffff")}${parts.join("")}</g>`,
  };
}

// --- The screen ---------------------------------------------------------------

const headerY = SAFE_TOP;
const cardY = headerY + NAV_HEIGHT + M.sectionGap;
const card = editorCard(GUTTER, cardY, CONTENT_W);
const previewY = cardY + card.height + M.sectionGap;
const actionY = POINTS.h - SAFE_BOTTOM - M.sectionGap - M.actionHeight;

// The scroll area ends where the pinned save row begins: whatever the preview
// card leaves below that line is under the row in the app, so it is clipped here.
const previewSize = M.preview;
const qr = renderQR({
  content: ical,
  size: previewSize,
  roundness: 0.35,
  eyeStyle: "rounded",
  gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 },
  errorCorrection: "M",
  gradientId: "pasteQR",
});

const screen = `
  ${header({ x: GUTTER, y: headerY, width: CONTENT_W })}
  ${card.svg}
  <defs><clipPath id="scrollClip"><rect x="0" y="0" width="${POINTS.w}" height="${actionY - M.sectionGap}"/></clipPath></defs>
  <g clip-path="url(#scrollClip)">
    ${previewCard({
      x: GUTTER, y: previewY, width: CONTENT_W, qr, previewSize,
      kind: S("dataType.icalendar"), content: `${L.exampleTitle} · ${day} ${time(start)}`,
    })}
  </g>
  ${actionRow({ x: GUTTER, y: actionY, width: CONTENT_W, label: L.save })}
`;

// --- The pasted text, above the phone -----------------------------------------

/** A note of what was pasted, overlapping the phone's top edge, pointing into it. */
function pastedNote() {
  const w = CANVAS.w - 260;
  const x = (CANVAS.w - w) / 2;
  const y = 520;
  // The width table underestimates this weight a little: leave it room to be wrong.
  const size = fitFontSize([L.pastedExample], w - 150, 46);
  const h = 170;
  return `<g filter="url(#cardShadow)">
    <rect x="${x}" y="${y}" width="${w}" height="${h}" rx="36" fill="#ffffff"/>
    <path d="M${CANVAS.w / 2 - 26} ${y + h - 1} L${CANVAS.w / 2} ${y + h + 30} L${CANVAS.w / 2 + 26} ${y + h - 1} Z" fill="#ffffff"/>
    <text x="${x + 45}" y="${y + 58}" font-family="${POSTER_FONT}" font-size="26" font-weight="700"
      fill="${INK.railActive}" letter-spacing="2">${escapeXML(L.pastedLabel.toUpperCase())}</text>
    <text x="${x + 45}" y="${y + 124}" font-family="${POSTER_FONT}" font-size="${size}" font-weight="600"
      fill="${INK.label}">${escapeXML(L.pastedExample)}</text>
  </g>`;
}

const inner = `
  ${headlineBlock(L.headline)}
  ${phoneScreen(screen)}
  ${pastedNote()}
  ${subtitleBlock(L.subtitle, { y: PHONE.y + PHONE.h + 150 })}
  ${signatureBlock(L)}
`;

writeScene("02b-paste-iphone-6.9", LOCALE, svgShell(inner, screenDefs()));
