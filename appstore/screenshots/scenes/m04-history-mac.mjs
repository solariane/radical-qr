/**
 * m04-history-mac.mjs — the Pro feature that only makes sense with a keyboard
 * and a big screen: everything you have made, searchable, and reopenable.
 *
 * `HistoryView` is a `List` with a `.searchable` field and a `.navigationTitle`,
 * each row a thumbnail, a title and a relative date. That is what is drawn — the
 * sidebar's History row is the selected one, because that is how you get here.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { writeScene } from "../lib/poster.mjs";
import {
  MAC_POINTS, MAC_SIDEBAR_W, MAC_FONT, MAC_COLORS,
  macWindow, macSidebar, macShell, macHeadline, macSubtitle, macSignature,
} from "../lib/mac-frame.mjs";
import { INK, text, ellipsize } from "../lib/app-ui.mjs";
import { symbol } from "../lib/symbols.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("history", LOCALE);

const ITEMS = [
  { title: "radicalsolution.com/radical-qr", kind: "URL", when: "2 min ago", content: "https://radicalsolution.com/radical-qr", roundness: 0.6, eyeStyle: "leaf", eyeScale: 0.9, gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 } },
  { title: "Wi-Fi — Studio", kind: "Wi-Fi", when: "1 h ago", content: "WIFI:T:WPA;S:Studio;P:radical2026;;", roundness: 0.3, eyeStyle: "rounded", color: "#1E3A5F" },
  { title: "Nicolas Lescure", kind: "Contact", when: "Yesterday", content: "BEGIN:VCARD\nVERSION:3.0\nN:Lescure;Nicolas\nEND:VCARD", roundness: 1, eyeStyle: "dot", gradient: { start: "#3B82F6", end: "#38C8D5", angle: 135 } },
  { title: "Menu — Le Verre", kind: "URL", when: "Yesterday", content: "https://leverre.example/menu", roundness: 0, eyeStyle: "square", color: "#722F37" },
  { title: "Vernissage — 14 Mar", kind: "Event", when: "3 days ago", content: "BEGIN:VEVENT\nSUMMARY:Vernissage\nEND:VEVENT", roundness: 0.6, eyeStyle: "rounded", color: "#2D5A3D" },
  { title: "contact@radicalsolution.com", kind: "Email", when: "1 week ago", content: "mailto:contact@radicalsolution.com", roundness: 0.3, eyeStyle: "square", gradient: { start: "#F97316", end: "#EC4E8D", angle: 135 } },
];

/** The detail pane: title, search field, then the list. */
function historyPane() {
  const x = MAC_SIDEBAR_W;
  const width = MAC_POINTS.w - MAC_SIDEBAR_W;
  const pad = 20;
  const searchY = 62;
  const rowH = 66;
  const listY = searchY + 46;

  const rows = ITEMS.map((item, i) => {
    const y = listY + i * rowH;
    const qr = renderQR({
      ...item, size: 42, quietZone: 0, errorCorrection: "M", gradientId: `histQR${i}`,
    });
    return `
      ${i > 0 ? `<rect x="${x + pad + 62}" y="${y}" width="${width - pad * 2 - 62}" height="1" fill="#ffffff" opacity="0.16"/>` : ""}
      <rect x="${x + pad}" y="${y + 10}" width="46" height="46" rx="7" fill="#ffffff"/>
      <g transform="translate(${x + pad + 2} ${y + 12})">${qr}</g>
      ${text(x + pad + 62, y + 31, ellipsize(item.title, width - pad * 2 - 200, 13.5), {
        size: 13.5, weight: 600, fill: "#ffffff", family: MAC_FONT,
      })}
      ${text(x + pad + 62, y + 48, `${item.kind}  •  ${item.when}`, {
        size: 11, fill: "#ffffff", opacity: 0.72, family: MAC_FONT,
      })}
      ${symbol("doc.on.doc", x + width - pad - 20, y + 33, 15, "#ffffff", "regular")}`;
  }).join("");

  return `<g>
    ${text(x + pad, 40, L.title, { size: 22, weight: 700, fill: "#ffffff", family: MAC_FONT })}
    <rect x="${x + pad}" y="${searchY}" width="${width - pad * 2}" height="32" rx="8" fill="#ffffff" fill-opacity="0.16"/>
    ${text(x + pad + 14, searchY + 21, L.searchPlaceholder, {
      size: 12.5, fill: "#ffffff", opacity: 0.6, family: MAC_FONT,
    })}
    ${rows}
  </g>`;
}

const body = `
  ${macSidebar({ copy: L, active: "history" })}
  ${historyPane()}
`;

writeScene("m04-history-mac", LOCALE, macShell(`
  ${macHeadline(L.headline)}
  ${macWindow(body)}
  ${macSubtitle(L.subtitle)}
  ${macSignature(L)}
`));
