/**
 * mac-frame.mjs — shared Mac 2880 × 1800 mockup geometry + SVG helpers.
 *
 * The app uses `.windowStyle(.hiddenTitleBar)` — no traditional title bar text,
 * just three traffic lights floating over the content. That's what we mimic.
 */

export const MAC_CANVAS = { w: 2880, h: 1800 };

export const MAC_COLORS = {
  bgStart: "#667eea",
  bgEnd: "#764ba2",
  windowOutline: "#1f1f2a",
  trafficRed: "#ff5f57",
  trafficYellow: "#febc2e",
  trafficGreen: "#28c840",
  sidebar: "#f3f3f7",
  sidebarActive: "#e6e5f2",
  sidebarText: "#1c1c20",
  sidebarTextMuted: "#6a6a72",
  screenBgStart: "#7b8fef",
  screenBgEnd: "#8a5fb8",
  qrGradientStart: "#4D33D9",
  qrGradientEnd: "#8C3BBF",
};

export const MAC_FONT = `-apple-system, 'SF Pro Display', 'Helvetica Neue', Helvetica, Arial, sans-serif`;

// Window geometry — centered, with generous padding so the headline + subtitle fit above / below.
export const WINDOW = {
  w: 2100,
  h: 1280,
  x: (MAC_CANVAS.w - 2100) / 2,
  y: 340,
  radius: 22,
};

export const SIDEBAR = {
  w: 360,
};

// Content area (right of the sidebar, inside the window)
export const CONTENT = {
  x: WINDOW.x + SIDEBAR.w,
  y: WINDOW.y,
  w: WINDOW.w - SIDEBAR.w,
  h: WINDOW.h,
};

export function macDefs() {
  return `
    <linearGradient id="macBgG" x1="0" y1="0" x2="${MAC_CANVAS.w}" y2="${MAC_CANVAS.h}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${MAC_COLORS.bgStart}"/>
      <stop offset="1" stop-color="${MAC_COLORS.bgEnd}"/>
    </linearGradient>
    <linearGradient id="macScreenG" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${MAC_COLORS.screenBgStart}"/>
      <stop offset="1" stop-color="${MAC_COLORS.screenBgEnd}"/>
    </linearGradient>
    <linearGradient id="macCtaG" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${MAC_COLORS.qrGradientStart}"/>
      <stop offset="1" stop-color="${MAC_COLORS.qrGradientEnd}"/>
    </linearGradient>
    <filter id="macWindowShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="30"/>
      <feOffset dx="0" dy="24" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.45"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="macCardShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="14"/>
      <feOffset dx="0" dy="10" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.22"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  `;
}

export function macBackground() {
  return `<rect x="0" y="0" width="${MAC_CANVAS.w}" height="${MAC_CANVAS.h}" fill="url(#macBgG)"/>`;
}

/**
 * Renders the window shell: rounded outer rect, sidebar, traffic lights.
 * Call macContentArea() for the right-side content of the window.
 */
export function macWindowShell({ activeSidebar = "generator", proBadge = false } = {}) {
  const lights = [
    [MAC_COLORS.trafficRed, 44],
    [MAC_COLORS.trafficYellow, 44 + 36],
    [MAC_COLORS.trafficGreen, 44 + 72],
  ];

  // Sidebar content
  const sbX = WINDOW.x;
  const sbY = WINDOW.y;
  const sbW = SIDEBAR.w;
  const sbH = WINDOW.h;

  // Sidebar nav items
  const NAV_Y = sbY + 140;
  const NAV_H = 56;
  const NAV_GAP = 14;
  const navItems = [
    { id: "generator", icon: "qrcode",  label: "Generator" },
    { id: "history",   icon: "clock",   label: "History",  pro: true },
    { id: "help",      icon: "help",    label: "Help" },
  ];

  const navSvg = navItems.map((it, i) => {
    const y = NAV_Y + i * (NAV_H + NAV_GAP);
    const active = it.id === activeSidebar;
    const bg = active
      ? `<rect x="${sbX + 16}" y="${y}" width="${sbW - 32}" height="${NAV_H}" rx="12" ry="12" fill="${MAC_COLORS.sidebarActive}"/>`
      : "";
    const textColor = active ? MAC_COLORS.sidebarText : MAC_COLORS.sidebarText;
    const iconColor = active ? MAC_COLORS.qrGradientStart : MAC_COLORS.sidebarTextMuted;
    const proMini = it.pro && proBadge
      ? `<rect x="${sbX + sbW - 78}" y="${y + 16}" width="52" height="26" rx="13" ry="13" fill="#ffb800"/>
         <text x="${sbX + sbW - 52}" y="${y + 34}" text-anchor="middle" font-size="16" font-weight="700" fill="#1a1a2a" font-family="${MAC_FONT}">PRO</text>`
      : "";
    return `
      ${bg}
      <g transform="translate(${sbX + 34} ${y + NAV_H / 2})">${navIcon(it.icon, iconColor)}</g>
      <text x="${sbX + 80}" y="${y + NAV_H / 2 + 10}" font-size="24" font-weight="500" fill="${textColor}" font-family="${MAC_FONT}">${it.label}</text>
      ${proMini}
    `;
  }).join("");

  return `
    <g filter="url(#macWindowShadow)">
      <!-- Window rounded rect (clipping bg) -->
      <rect x="${WINDOW.x}" y="${WINDOW.y}" width="${WINDOW.w}" height="${WINDOW.h}" rx="${WINDOW.radius}" ry="${WINDOW.radius}" fill="#ffffff"/>
      <!-- Sidebar -->
      <rect x="${sbX}" y="${sbY}" width="${sbW}" height="${sbH}" rx="${WINDOW.radius}" ry="${WINDOW.radius}" fill="${MAC_COLORS.sidebar}"/>
      <!-- Rectangle mask to "square" the right edge of the sidebar (otherwise its right corners are rounded) -->
      <rect x="${sbX + sbW - WINDOW.radius}" y="${sbY}" width="${WINDOW.radius}" height="${sbH}" fill="${MAC_COLORS.sidebar}"/>
      <!-- Sidebar divider -->
      <line x1="${sbX + sbW}" y1="${sbY}" x2="${sbX + sbW}" y2="${sbY + sbH}" stroke="#d8d8e0" stroke-width="1"/>
    </g>

    <!-- Traffic lights -->
    <g>
      <circle cx="${WINDOW.x + 44}" cy="${WINDOW.y + 38}" r="11" fill="${MAC_COLORS.trafficRed}"/>
      <circle cx="${WINDOW.x + 44 + 30}" cy="${WINDOW.y + 38}" r="11" fill="${MAC_COLORS.trafficYellow}"/>
      <circle cx="${WINDOW.x + 44 + 60}" cy="${WINDOW.y + 38}" r="11" fill="${MAC_COLORS.trafficGreen}"/>
    </g>

    <!-- Sidebar app name -->
    <text x="${sbX + 34}" y="${sbY + 86}" font-size="18" font-weight="700" fill="${MAC_COLORS.sidebarTextMuted}" letter-spacing="2" font-family="${MAC_FONT}">RADICAL QR</text>

    ${navSvg}
  `;
}

/** Minimal SF-Symbols-ish icons for the sidebar. */
function navIcon(kind, color) {
  const stroke = `stroke="${color}" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round" fill="none"`;
  switch (kind) {
    case "qrcode":
      return `
        <rect x="-14" y="-14" width="10" height="10" rx="2" ${stroke}/>
        <rect x="4"   y="-14" width="10" height="10" rx="2" ${stroke}/>
        <rect x="-14" y="4"   width="10" height="10" rx="2" ${stroke}/>
        <rect x="6"   y="6"   width="3"  height="3"  ${stroke}/>
        <rect x="12"  y="12"  width="3"  height="3"  ${stroke}/>
      `;
    case "clock":
      return `
        <circle cx="0" cy="0" r="13" ${stroke}/>
        <line x1="0" y1="0" x2="0" y2="-8" ${stroke}/>
        <line x1="0" y1="0" x2="7" y2="3" ${stroke}/>
      `;
    case "help":
      return `
        <circle cx="0" cy="0" r="13" ${stroke}/>
        <path d="M -5 -4 Q 0 -10 5 -6 Q 8 -3 4 1 Q 0 4 0 7" ${stroke}/>
        <circle cx="0" cy="11" r="1.5" fill="${color}"/>
      `;
  }
  return "";
}

export function macHeadline(lines, { y1 = 180, y2 = 330 } = {}) {
  return `
    <g text-anchor="middle" fill="#ffffff" font-family="${MAC_FONT}">
      <text x="${MAC_CANVAS.w / 2}" y="${y1}" font-size="130" font-weight="700" letter-spacing="-2">${escapeXML(lines[0])}</text>
      ${lines[1] ? `<text x="${MAC_CANVAS.w / 2}" y="${y2}" font-size="130" font-weight="700" letter-spacing="-2" opacity="0.92">${escapeXML(lines[1])}</text>` : ""}
    </g>
  `;
}

export function macSubtitle(text, { y = WINDOW.y + WINDOW.h + 120, lineHeight = 64 } = {}) {
  const lines = Array.isArray(text) ? text : [text];
  const tspans = lines.map((line, i) =>
    `<text x="${MAC_CANVAS.w / 2}" y="${y + i * lineHeight}" font-size="48" font-weight="500" opacity="0.95">${escapeXML(line)}</text>`
  ).join("");
  return `
    <g text-anchor="middle" font-family="${MAC_FONT}" fill="#ffffff">
      ${tspans}
    </g>
  `;
}

export function macShell(innerSVG) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${MAC_CANVAS.w} ${MAC_CANVAS.h}" width="${MAC_CANVAS.w}" height="${MAC_CANVAS.h}">
  <defs>${macDefs()}</defs>
  ${macBackground()}
  ${innerSVG}
</svg>
`;
}

export function escapeXML(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
