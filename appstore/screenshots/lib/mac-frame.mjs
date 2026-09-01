/**
 * mac-frame.mjs — Mac poster (2880 × 1800).
 *
 * macOS is the one platform that really does split: `ContentView` wraps the
 * generator in a `NavigationSplitView` there, and only there. So this frame
 * draws the sidebar the app has, and hands the detail pane to `screens.mjs` —
 * the same generator the phone and the iPad draw.
 *
 * The window is 1160 × 780 points, which is a plausible size for a window whose
 * minimum is 780 × 620 and, at 780pt tall, the side of the 700pt line where
 * `GeneratorMetrics.regular` applies. The app uses `.windowStyle(.hiddenTitleBar)`,
 * so there is no title bar — just three traffic lights over the sidebar.
 */

import { appScreen, appScreenDefs, fitFontSize, text, INK } from "./app-ui.mjs";
import { symbol } from "./symbols.mjs";
import { signature } from "./signature.mjs";

export const MAC_CANVAS = { w: 2880, h: 1800 };

export const MAC_COLORS = {
  bgStart: "#667eea",
  bgEnd: "#764ba2",
  trafficRed: "#ff5f57",
  trafficYellow: "#febc2e",
  trafficGreen: "#28c840",
  sidebar: "#F2F1F6",
  sidebarActive: "#E3E1EE",
  sidebarText: "#1C1C20",
  sidebarTextMuted: "#6A6A72",
};

export const MAC_FONT = `-apple-system, 'SF Pro Display', 'SF Pro Text', 'Helvetica Neue', Helvetica, Arial, sans-serif`;

/** 1160 × 780 points at 1.603 — see the note above on why that size. */
export const WINDOW = {
  w: 1940,
  h: 1305,
  x: (MAC_CANVAS.w - 1940) / 2,
  y: 205,
  radius: 22,
};

export const MAC_POINTS = { w: 1160, h: WINDOW.h / (WINDOW.w / 1160) };
export const MAC_SCALE = WINDOW.w / MAC_POINTS.w;
/** SwiftUI's default sidebar width in a two-column split view. */
export const MAC_SIDEBAR_W = 188;
export const MAC_GUTTER = 16;

/** The detail pane, in points — what `generatorScreen` is laid out inside. */
export const MAC_DETAIL = {
  x: MAC_SIDEBAR_W,
  w: MAC_POINTS.w - MAC_SIDEBAR_W,
  h: MAC_POINTS.h,
};

export function macDefs(win = WINDOW) {
  return `
    <linearGradient id="macBgG" x1="0" y1="0" x2="${MAC_CANVAS.w}" y2="${MAC_CANVAS.h}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${MAC_COLORS.bgStart}"/>
      <stop offset="1" stop-color="${MAC_COLORS.bgEnd}"/>
    </linearGradient>
    <filter id="macWindowShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="30"/>
      <feOffset dx="0" dy="24" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.45"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="macCardShadow" x="-12%" y="-12%" width="124%" height="124%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="16"/>
      <feOffset dx="0" dy="12" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.3"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    ${appScreenDefs({ screen: win, gradientId: "macAppG", radius: win.radius })}
  `;
}

export function macBackground() {
  return `<rect x="0" y="0" width="${MAC_CANVAS.w}" height="${MAC_CANVAS.h}" fill="url(#macBgG)"/>`;
}

/**
 * The sidebar `ContentView.sidebarContent` builds: Generator, History, then a
 * section with Help. Drawn in points, inside the window.
 *
 * @param {"generator" | "history"} active
 */
export function macSidebar({ copy, active = "generator" }) {
  const rowH = 30;
  const top = 68;
  const rows = [
    { key: "generator", label: copy.sidebarGenerator, icon: "qrcode" },
    { key: "history", label: copy.sidebarHistory, icon: "clock.arrow.circlepath" },
  ];

  const list = rows.map((row, i) => {
    const y = top + i * (rowH + 4);
    const isActive = row.key === active;
    return `
      ${isActive ? `<rect x="8" y="${y}" width="${MAC_SIDEBAR_W - 16}" height="${rowH}" rx="7" fill="${MAC_COLORS.sidebarActive}"/>` : ""}
      ${symbol(row.icon, 26, y + rowH / 2, 14, isActive ? INK.railActive : MAC_COLORS.sidebarTextMuted, "medium")}
      ${text(42, y + rowH / 2 + 4.5, row.label, {
        size: 13, weight: isActive ? 600 : 400,
        fill: isActive ? INK.railActive : MAC_COLORS.sidebarText, family: MAC_FONT,
      })}`;
  }).join("");

  const helpY = top + rows.length * (rowH + 4) + 26;

  return `<g>
    <rect x="0" y="0" width="${MAC_SIDEBAR_W}" height="${MAC_POINTS.h}" fill="${MAC_COLORS.sidebar}"/>
    ${trafficLights()}
    ${text(18, 52, copy.appName ?? "Radical QR", {
      size: 15, weight: 700, fill: MAC_COLORS.sidebarText, family: MAC_FONT,
    })}
    ${list}
    <rect x="18" y="${helpY - 16}" width="${MAC_SIDEBAR_W - 36}" height="1" fill="${MAC_COLORS.sidebarTextMuted}" opacity="0.22"/>
    ${symbol("questionmark.circle", 26, helpY + rowH / 2, 14, MAC_COLORS.sidebarTextMuted, "medium")}
    ${text(42, helpY + rowH / 2 + 4.5, copy.sidebarHelp, {
      size: 13, fill: MAC_COLORS.sidebarText, family: MAC_FONT,
    })}
  </g>`;
}

/** `.windowStyle(.hiddenTitleBar)`: the lights float, there is no bar. */
export function trafficLights(x = 18, y = 18) {
  return [MAC_COLORS.trafficRed, MAC_COLORS.trafficYellow, MAC_COLORS.trafficGreen]
    .map((fill, i) => `<circle cx="${x + i * 18}" cy="${y}" r="6" fill="${fill}"/>`)
    .join("");
}

/**
 * Window shell with the app drawn inside it in points. `body` is expected to
 * cover the whole 1160 × 780 space — sidebar included.
 */
export function macWindow(body, win = WINDOW) {
  return `
    <g filter="url(#macWindowShadow)">
      ${appScreen({ screen: win, points: MAC_POINTS, gradientId: "macAppG", body })}
    </g>
  `;
}

/**
 * A smaller window, keeping the 1160 × 780 point ratio so the app inside is
 * unchanged — only its scale. Scenes that need margin for poster content (the
 * privacy claims, a menu callout) place one of these instead of the default.
 */
export function macWindowRect({ w, x, y }) {
  const h = Math.round(w * (MAC_POINTS.h / MAC_POINTS.w));
  return { w, h, x: x ?? (MAC_CANVAS.w - w) / 2, y, radius: WINDOW.radius };
}

export function macHeadline(lines, { y = 140, maxWidth = MAC_CANVAS.w - 400 } = {}) {
  // One line on Mac: the window is wide and short, so a stacked headline would
  // squeeze it. Scenes pass their two lines and they are joined with a space.
  const joined = lines.filter(Boolean).join(" ");
  const size = fitFontSize([joined], maxWidth, 110);
  return `<text x="${MAC_CANVAS.w / 2}" y="${y}" text-anchor="middle" font-family="${MAC_FONT}"
    font-size="${size}" font-weight="700" letter-spacing="${-2.5 * size / 110}" fill="#ffffff">${macEscape(joined)}</text>`;
}

export function macSubtitle(lines, { y = WINDOW.y + WINDOW.h + 96, lineHeight = 64, maxWidth = MAC_CANVAS.w - 400 } = {}) {
  const list = Array.isArray(lines) ? lines : [lines];
  const size = fitFontSize(list, maxWidth, 50);
  const step = lineHeight * (size / 50);
  return `<g text-anchor="middle" font-family="${MAC_FONT}" fill="#ffffff">
    ${list.map((line, i) =>
      `<text x="${MAC_CANVAS.w / 2}" y="${y + i * step}" font-size="${size}" font-weight="500" opacity="0.95">${macEscape(line)}</text>`
    ).join("")}
  </g>`;
}

export function macSignature(copy, { y = MAC_CANVAS.h - 62 } = {}) {
  return signature({ centerX: MAC_CANVAS.w / 2, y, copy, size: 36 });
}

export function macShell(innerSVG, win = WINDOW) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${MAC_CANVAS.w} ${MAC_CANVAS.h}" width="${MAC_CANVAS.w}" height="${MAC_CANVAS.h}">
  <defs>${macDefs(win)}</defs>
  ${macBackground()}
  ${innerSVG}
</svg>
`;
}

export function macEscape(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
