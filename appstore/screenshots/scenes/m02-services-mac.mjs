/**
 * m02-services-mac.mjs — macOS Services integration, the Mac-only differentiator.
 * Split layout:
 *   Left  — a simulated "Contacts" window with a contextual menu open,
 *           "Services → Generate QR Code" highlighted
 *   Right — the Radical QR window showing the resulting QR for that contact
 */

import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { renderQR } from "../lib/qr-svg.mjs";
import {
  MAC_CANVAS, MAC_COLORS, MAC_FONT,
  macShell, macHeadline, macSubtitle, escapeXML,
} from "../lib/mac-frame.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.resolve(__dirname, "../out");
const LOCALE = process.argv[2] || "en-US";

const COPY = {
  "en-US": {
    headline: ["Right-click.", "Scan."],
    subtitle: "Generate a QR from any app. Contacts, Safari, Calendar, Finder.",
    sourceAppTitle: "Contacts",
    contactName: "Claire Dubois",
    contactRole: "Designer · Paris",
    menuItems: [
      { label: "Edit Card", kbd: "⌘E" },
      { label: "Share Card…", kbd: "" },
      { label: "Export vCard…", kbd: "" },
      { kind: "divider" },
      { label: "Services", submenu: true, active: true },
    ],
    submenuItems: [
      { label: "Add to Reminders", icon: "📋" },
      { label: "New Email With Selection", icon: "✉️" },
      { label: "Generate QR Code", icon: "🔳", highlight: true },
      { label: "Search with Google", icon: "🔍" },
    ],
    rightAppTitle: "QR Code Generator",
    rightChipTitle: "Contact",
    rightChipDetail: "Claire Dubois · claire@example.com",
  },
  "fr-FR": {
    headline: ["Clic droit.", "Scan."],
    subtitle: "Un QR depuis n'importe quelle app. Contacts, Safari, Calendar, Finder.",
    sourceAppTitle: "Contacts",
    contactName: "Claire Dubois",
    contactRole: "Designer · Paris",
    menuItems: [
      { label: "Modifier", kbd: "⌘E" },
      { label: "Partager la carte…", kbd: "" },
      { label: "Exporter vCard…", kbd: "" },
      { kind: "divider" },
      { label: "Services", submenu: true, active: true },
    ],
    submenuItems: [
      { label: "Ajouter aux rappels", icon: "📋" },
      { label: "Nouveau message", icon: "✉️" },
      { label: "Générer un QR Code", icon: "🔳", highlight: true },
      { label: "Rechercher sur Google", icon: "🔍" },
    ],
    rightAppTitle: "Générateur de QR Code",
    rightChipTitle: "Contact",
    rightChipDetail: "Claire Dubois · claire@exemple.fr",
  },
};
const L = COPY[LOCALE] ?? COPY["en-US"];

// ---- Layout: two windows side-by-side -----------------------------------
const TOP_MARGIN = 380;        // below the headline
const SIDE_MARGIN = 120;
const COL_GAP = 80;
const WIN_H = 1220;

const colW = (MAC_CANVAS.w - SIDE_MARGIN * 2 - COL_GAP) / 2;
const LEFT_X = SIDE_MARGIN;
const RIGHT_X = SIDE_MARGIN + colW + COL_GAP;
const TOP_Y = TOP_MARGIN;

// ---- Source (Contacts) window -------------------------------------------
const SRC = { x: LEFT_X, y: TOP_Y, w: colW, h: WIN_H, radius: 20 };
const SRC_SIDEBAR_W = 220;

// Contextual menu just right of the contact row
const CM = { x: SRC.x + 380, y: SRC.y + 260, w: 360, h: 300, radius: 10 };
const SUB = { x: CM.x + CM.w + 6, y: CM.y + 192, w: 420, h: 240, radius: 10 };

// ---- Right: Radical QR window --------------------------------------------
const RQR = { x: RIGHT_X, y: TOP_Y, w: colW, h: WIN_H, radius: 22 };

// QR inside the right window
const RQR_QR_SIZE = 520;
const RQR_QR_X = RQR.x + (RQR.w - RQR_QR_SIZE) / 2;
const RQR_QR_Y = RQR.y + 420;

const rqrSvg = renderQR({
  content: "BEGIN:VCARD\nFN:Claire Dubois\nEMAIL:claire@example.com\nEND:VCARD",
  size: RQR_QR_SIZE,
  roundness: 0.3,
  eyeRoundness: 1.0,
  eyeScale: 0.88,
  gradient: { start: MAC_COLORS.qrGradientStart, end: MAC_COLORS.qrGradientEnd, angle: 135 },
  background: "#ffffff",
  errorCorrection: "H",
  gradientId: "servicesQr",
});

// Menu item renderer
function menuItem(parentX, parentW, y, item, index) {
  if (item.kind === "divider") {
    return `<line x1="${parentX + 12}" y1="${y + 14}" x2="${parentX + parentW - 12}" y2="${y + 14}" stroke="#00000022" stroke-width="1"/>`;
  }
  const bg = item.active
    ? `<rect x="${parentX + 6}" y="${y - 2}" width="${parentW - 12}" height="36" rx="6" ry="6" fill="#0066ff"/>`
    : "";
  const color = item.active ? "#ffffff" : "#1c1c20";
  const chevron = item.submenu
    ? `<text x="${parentX + parentW - 18}" y="${y + 22}" text-anchor="end" font-size="18" fill="${color}" font-family="${MAC_FONT}">▸</text>`
    : "";
  const kbd = item.kbd
    ? `<text x="${parentX + parentW - 18}" y="${y + 22}" text-anchor="end" font-size="15" fill="${color}" opacity="0.6" font-family="${MAC_FONT}">${escapeXML(item.kbd)}</text>`
    : "";
  return `
    ${bg}
    <text x="${parentX + 18}" y="${y + 22}" font-size="17" fill="${color}" font-family="${MAC_FONT}">${escapeXML(item.label)}</text>
    ${item.submenu ? chevron : kbd}
  `;
}

function submenuItem(parentX, parentW, y, item) {
  const bg = item.highlight
    ? `<rect x="${parentX + 6}" y="${y - 2}" width="${parentW - 12}" height="44" rx="6" ry="6" fill="#0066ff"/>`
    : "";
  const color = item.highlight ? "#ffffff" : "#1c1c20";
  return `
    ${bg}
    <text x="${parentX + 20}" y="${y + 28}" font-size="22" font-family="${MAC_FONT}">${escapeXML(item.icon)}</text>
    <text x="${parentX + 58}" y="${y + 28}" font-size="18" fill="${color}" font-family="${MAC_FONT}">${escapeXML(item.label)}</text>
  `;
}

const menuRowH = 36;
const menuPadding = 10;
const submenuRowH = 44;

const inner = `
  ${macHeadline(L.headline)}

  <!-- Source (Contacts) window -->
  <g filter="url(#macWindowShadow)">
    <rect x="${SRC.x}" y="${SRC.y}" width="${SRC.w}" height="${SRC.h}" rx="${SRC.radius}" ry="${SRC.radius}" fill="#ffffff"/>
    <!-- Sidebar -->
    <rect x="${SRC.x}" y="${SRC.y}" width="${SRC_SIDEBAR_W}" height="${SRC.h}" rx="${SRC.radius}" ry="${SRC.radius}" fill="#f3f3f7"/>
    <rect x="${SRC.x + SRC_SIDEBAR_W - SRC.radius}" y="${SRC.y}" width="${SRC.radius}" height="${SRC.h}" fill="#f3f3f7"/>
    <line x1="${SRC.x + SRC_SIDEBAR_W}" y1="${SRC.y}" x2="${SRC.x + SRC_SIDEBAR_W}" y2="${SRC.y + SRC.h}" stroke="#d8d8e0" stroke-width="1"/>
  </g>

  <!-- Traffic lights -->
  <g>
    <circle cx="${SRC.x + 28}" cy="${SRC.y + 28}" r="9" fill="${MAC_COLORS.trafficRed}"/>
    <circle cx="${SRC.x + 28 + 22}" cy="${SRC.y + 28}" r="9" fill="${MAC_COLORS.trafficYellow}"/>
    <circle cx="${SRC.x + 28 + 44}" cy="${SRC.y + 28}" r="9" fill="${MAC_COLORS.trafficGreen}"/>
    <text x="${SRC.x + SRC.w / 2}" y="${SRC.y + 34}" text-anchor="middle" font-size="16" font-weight="600" fill="#1c1c20" font-family="${MAC_FONT}">${escapeXML(L.sourceAppTitle)}</text>
  </g>

  <!-- Sidebar groups -->
  <g font-family="${MAC_FONT}" fill="#1c1c20">
    <text x="${SRC.x + 20}" y="${SRC.y + 88}" font-size="13" font-weight="700" fill="#6a6a72" letter-spacing="1">iCloud</text>
    <text x="${SRC.x + 20}" y="${SRC.y + 124}" font-size="15">👥 All Contacts</text>
    <text x="${SRC.x + 20}" y="${SRC.y + 156}" font-size="15" opacity="0.6">⭐ Favorites</text>
    <text x="${SRC.x + 20}" y="${SRC.y + 188}" font-size="15" opacity="0.6">💼 Work</text>
  </g>

  <!-- Contact row (active/selected) -->
  <g>
    <rect x="${SRC.x + SRC_SIDEBAR_W}" y="${SRC.y + 70}" width="${SRC.w - SRC_SIDEBAR_W}" height="80" fill="#0066ff" opacity="0.1"/>
    <circle cx="${SRC.x + SRC_SIDEBAR_W + 40}" cy="${SRC.y + 110}" r="22" fill="url(#macCtaG)"/>
    <text x="${SRC.x + SRC_SIDEBAR_W + 40}" y="${SRC.y + 118}" text-anchor="middle" font-size="22" font-weight="700" fill="#ffffff" font-family="${MAC_FONT}">C</text>
    <text x="${SRC.x + SRC_SIDEBAR_W + 80}" y="${SRC.y + 105}" font-size="18" font-weight="600" fill="#1c1c20" font-family="${MAC_FONT}">${escapeXML(L.contactName)}</text>
    <text x="${SRC.x + SRC_SIDEBAR_W + 80}" y="${SRC.y + 128}" font-size="14" fill="#6a6a72" font-family="${MAC_FONT}">${escapeXML(L.contactRole)}</text>
  </g>

  <!-- Detail card for the contact (grayed) -->
  <g opacity="0.35" font-family="${MAC_FONT}" fill="#1c1c20">
    <rect x="${SRC.x + SRC_SIDEBAR_W + 30}" y="${SRC.y + 200}" width="${SRC.w - SRC_SIDEBAR_W - 60}" height="120" rx="10" ry="10" fill="#f7f7fa"/>
    <text x="${SRC.x + SRC_SIDEBAR_W + 52}" y="${SRC.y + 238}" font-size="14" font-weight="700" fill="#6a6a72">EMAIL</text>
    <text x="${SRC.x + SRC_SIDEBAR_W + 52}" y="${SRC.y + 266}" font-size="16">claire@example.com</text>
    <text x="${SRC.x + SRC_SIDEBAR_W + 52}" y="${SRC.y + 298}" font-size="14" font-weight="700" fill="#6a6a72">PHONE</text>
  </g>

  <!-- Contextual menu -->
  <g filter="url(#macCardShadow)">
    <rect x="${CM.x}" y="${CM.y}" width="${CM.w}" height="${CM.h}" rx="${CM.radius}" ry="${CM.radius}" fill="#ffffff" stroke="#00000022" stroke-width="1"/>
    ${L.menuItems.map((item, i) => {
      const y = CM.y + menuPadding + i * menuRowH;
      return menuItem(CM.x, CM.w, y, item, i);
    }).join("")}
  </g>

  <!-- Submenu (opened from "Services") -->
  <g filter="url(#macCardShadow)">
    <rect x="${SUB.x}" y="${SUB.y}" width="${SUB.w}" height="${SUB.h}" rx="${SUB.radius}" ry="${SUB.radius}" fill="#ffffff" stroke="#00000022" stroke-width="1"/>
    ${L.submenuItems.map((item, i) => {
      const y = SUB.y + menuPadding + i * submenuRowH;
      return submenuItem(SUB.x, SUB.w, y, item);
    }).join("")}
  </g>

  <!-- Arrow from submenu "Generate QR Code" to the right window -->
  <g>
    <path d="M ${SUB.x + SUB.w + 10} ${SUB.y + 2 * submenuRowH + 20}
             Q ${(SUB.x + SUB.w + RQR.x) / 2} ${SUB.y + 2 * submenuRowH + 20},
               ${RQR.x - 10} ${RQR.y + RQR.h / 2}"
          stroke="#ffffff" stroke-width="6" stroke-linecap="round" fill="none" stroke-dasharray="14 12" opacity="0.7"/>
    <polygon points="${RQR.x - 10},${RQR.y + RQR.h / 2} ${RQR.x - 36},${RQR.y + RQR.h / 2 - 14} ${RQR.x - 36},${RQR.y + RQR.h / 2 + 14}" fill="#ffffff" opacity="0.85"/>
  </g>

  <!-- Radical QR window -->
  <g filter="url(#macWindowShadow)">
    <rect x="${RQR.x}" y="${RQR.y}" width="${RQR.w}" height="${RQR.h}" rx="${RQR.radius}" ry="${RQR.radius}" fill="url(#macScreenG)"/>
  </g>

  <!-- Traffic lights (right window) -->
  <g>
    <circle cx="${RQR.x + 32}" cy="${RQR.y + 32}" r="10" fill="${MAC_COLORS.trafficRed}"/>
    <circle cx="${RQR.x + 32 + 26}" cy="${RQR.y + 32}" r="10" fill="${MAC_COLORS.trafficYellow}"/>
    <circle cx="${RQR.x + 32 + 52}" cy="${RQR.y + 32}" r="10" fill="${MAC_COLORS.trafficGreen}"/>
    <text x="${RQR.x + RQR.w / 2}" y="${RQR.y + 40}" text-anchor="middle" font-size="18" font-weight="600" fill="#ffffff" opacity="0.9" font-family="${MAC_FONT}">${escapeXML(L.rightAppTitle)}</text>
  </g>

  <!-- Summary chip inside right window -->
  <g>
    <rect x="${RQR.x + 70}" y="${RQR.y + 110}" width="${RQR.w - 140}" height="110" rx="18" ry="18" fill="#ffffff"/>
    <circle cx="${RQR.x + 115}" cy="${RQR.y + 165}" r="30" fill="#e8ebff"/>
    <text x="${RQR.x + 115}" y="${RQR.y + 173}" text-anchor="middle" font-size="28" fill="${MAC_COLORS.qrGradientStart}" font-family="${MAC_FONT}">👤</text>
    <text x="${RQR.x + 165}" y="${RQR.y + 155}" font-size="22" font-weight="600" fill="#222" font-family="${MAC_FONT}">${escapeXML(L.rightChipTitle)}</text>
    <text x="${RQR.x + 165}" y="${RQR.y + 185}" font-size="18" fill="#666" font-family="${MAC_FONT}">${escapeXML(L.rightChipDetail)}</text>
  </g>

  <!-- Data-type indicator -->
  <g>
    <rect x="${RQR.x + 70}" y="${RQR.y + 250}" width="${RQR.w - 140}" height="80" rx="18" ry="18" fill="#ffffff" opacity="0.22"/>
    <text x="${RQR.x + 90}" y="${RQR.y + 298}" font-size="20" font-weight="600" fill="#ffffff" font-family="${MAC_FONT}">👤 ${escapeXML(L.rightChipTitle + " card")}</text>
    <text x="${RQR.x + RQR.w - 90}" y="${RQR.y + 298}" text-anchor="end" font-size="16" fill="#ffffff" opacity="0.85" font-family="${MAC_FONT}">vCard · auto-detected</text>
  </g>

  <!-- QR card -->
  <g filter="url(#macCardShadow)">
    <rect x="${RQR_QR_X - 30}" y="${RQR_QR_Y - 30}" width="${RQR_QR_SIZE + 60}" height="${RQR_QR_SIZE + 60}" rx="22" ry="22" fill="#ffffff"/>
    <g transform="translate(${RQR_QR_X} ${RQR_QR_Y})">${rqrSvg}</g>
  </g>

  ${macSubtitle(L.subtitle)}
`;

fs.mkdirSync(OUT, { recursive: true });
const filename = `m02-services-mac-${LOCALE}.svg`;
fs.writeFileSync(path.join(OUT, filename), macShell(inner));
console.log("wrote", path.relative(process.cwd(), path.join(OUT, filename)));
