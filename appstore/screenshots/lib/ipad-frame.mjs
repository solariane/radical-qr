/**
 * ipad-frame.mjs — iPad Pro 13" portrait mockup (2064 × 2752).
 * Mirrors the NavigationSplitView layout the app shows on iPad:
 * sidebar on the left, main content on the right, all inside a
 * rounded-corner device silhouette with thin bezels.
 */

export const IPAD_CANVAS = { w: 2064, h: 2752 };

export const IPAD_COLORS = {
  bgStart: "#667eea",
  bgEnd: "#764ba2",
  deviceBezel: "#0f0f18",
  sidebar: "#f3f3f7",
  sidebarActive: "#e6e5f2",
  sidebarText: "#1c1c20",
  sidebarTextMuted: "#6a6a72",
  screenBgStart: "#7b8fef",
  screenBgEnd: "#8a5fb8",
  qrGradientStart: "#4D33D9",
  qrGradientEnd: "#8C3BBF",
};

export const IPAD_FONT = `-apple-system, 'SF Pro Display', 'Helvetica Neue', Helvetica, Arial, sans-serif`;

// Device layout inside the canvas
export const IPAD = {
  w: 1500,
  h: 2000,
  x: (IPAD_CANVAS.w - 1500) / 2,
  y: 520,
  bezel: 36,
  radius: 100,
};

export const IPAD_SCREEN = {
  x: IPAD.x + IPAD.bezel,
  y: IPAD.y + IPAD.bezel,
  w: IPAD.w - IPAD.bezel * 2,
  h: IPAD.h - IPAD.bezel * 2,
  radius: IPAD.radius - IPAD.bezel,
};

// Sidebar width (like NavigationSplitView default on iPad)
export const IPAD_SIDEBAR_W = 360;

// Main content area (right of the sidebar)
export const IPAD_CONTENT = {
  x: IPAD_SCREEN.x + IPAD_SIDEBAR_W,
  y: IPAD_SCREEN.y,
  w: IPAD_SCREEN.w - IPAD_SIDEBAR_W,
  h: IPAD_SCREEN.h,
};

export function ipadDefs() {
  return `
    <linearGradient id="ipadBgG" x1="0" y1="0" x2="${IPAD_CANVAS.w}" y2="${IPAD_CANVAS.h}" gradientUnits="userSpaceOnUse">
      <stop offset="0" stop-color="${IPAD_COLORS.bgStart}"/>
      <stop offset="1" stop-color="${IPAD_COLORS.bgEnd}"/>
    </linearGradient>
    <linearGradient id="ipadScreenG" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="${IPAD_COLORS.screenBgStart}"/>
      <stop offset="1" stop-color="${IPAD_COLORS.screenBgEnd}"/>
    </linearGradient>
    <linearGradient id="ipadCtaG" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${IPAD_COLORS.qrGradientStart}"/>
      <stop offset="1" stop-color="${IPAD_COLORS.qrGradientEnd}"/>
    </linearGradient>
    <filter id="ipadDeviceShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="28"/>
      <feOffset dx="0" dy="20" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.4"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
    <filter id="ipadCardShadow" x="-10%" y="-10%" width="120%" height="120%">
      <feGaussianBlur in="SourceAlpha" stdDeviation="14"/>
      <feOffset dx="0" dy="10" result="o"/>
      <feComponentTransfer><feFuncA type="linear" slope="0.22"/></feComponentTransfer>
      <feMerge><feMergeNode/><feMergeNode in="SourceGraphic"/></feMerge>
    </filter>
  `;
}

export function ipadBackground() {
  return `<rect x="0" y="0" width="${IPAD_CANVAS.w}" height="${IPAD_CANVAS.h}" fill="url(#ipadBgG)"/>`;
}

/**
 * iPad silhouette + sidebar shell. Draws:
 *   - device bezel (rounded rect)
 *   - screen (rounded rect, clipped)
 *   - sidebar with app logo + nav items
 */
export function ipadShell({ activeSidebar = "generator", proBadge = false } = {}) {
  const navItems = [
    { id: "generator", icon: "qrcode", label: "Generator" },
    { id: "history",   icon: "clock",  label: "History", pro: true },
    { id: "help",      icon: "help",   label: "Help" },
  ];

  const NAV_Y = IPAD_SCREEN.y + 180;
  const NAV_H = 76;
  const NAV_GAP = 18;

  const navSvg = navItems.map((it, i) => {
    const y = NAV_Y + i * (NAV_H + NAV_GAP);
    const active = it.id === activeSidebar;
    const bg = active
      ? `<rect x="${IPAD_SCREEN.x + 22}" y="${y}" width="${IPAD_SIDEBAR_W - 44}" height="${NAV_H}" rx="16" ry="16" fill="${IPAD_COLORS.sidebarActive}"/>`
      : "";
    const iconColor = active ? IPAD_COLORS.qrGradientStart : IPAD_COLORS.sidebarTextMuted;
    const proMini = it.pro && proBadge
      ? `<rect x="${IPAD_SCREEN.x + IPAD_SIDEBAR_W - 90}" y="${y + 24}" width="58" height="28" rx="14" ry="14" fill="#ffb800"/>
         <text x="${IPAD_SCREEN.x + IPAD_SIDEBAR_W - 61}" y="${y + 44}" text-anchor="middle" font-size="16" font-weight="700" fill="#1a1a2a" font-family="${IPAD_FONT}">PRO</text>`
      : "";
    return `
      ${bg}
      <g transform="translate(${IPAD_SCREEN.x + 48} ${y + NAV_H / 2})">${ipadNavIcon(it.icon, iconColor)}</g>
      <text x="${IPAD_SCREEN.x + 104}" y="${y + NAV_H / 2 + 10}" font-size="28" font-weight="500" fill="${IPAD_COLORS.sidebarText}" font-family="${IPAD_FONT}">${it.label}</text>
      ${proMini}
    `;
  }).join("");

  return `
    <g filter="url(#ipadDeviceShadow)">
      <rect x="${IPAD.x}" y="${IPAD.y}" width="${IPAD.w}" height="${IPAD.h}" rx="${IPAD.radius}" ry="${IPAD.radius}" fill="${IPAD_COLORS.deviceBezel}"/>
      <rect x="${IPAD_SCREEN.x}" y="${IPAD_SCREEN.y}" width="${IPAD_SCREEN.w}" height="${IPAD_SCREEN.h}" rx="${IPAD_SCREEN.radius}" ry="${IPAD_SCREEN.radius}" fill="${IPAD_COLORS.sidebar}"/>
    </g>

    <!-- App name at the top of the sidebar -->
    <text x="${IPAD_SCREEN.x + 48}" y="${IPAD_SCREEN.y + 130}" font-size="22" font-weight="700" fill="${IPAD_COLORS.sidebarTextMuted}" letter-spacing="2" font-family="${IPAD_FONT}">RADICAL QR</text>

    ${navSvg}
  `;
}

function ipadNavIcon(kind, color) {
  const stroke = `stroke="${color}" stroke-width="3" stroke-linecap="round" stroke-linejoin="round" fill="none"`;
  switch (kind) {
    case "qrcode":
      return `
        <rect x="-18" y="-18" width="14" height="14" rx="3" ${stroke}/>
        <rect x="4"   y="-18" width="14" height="14" rx="3" ${stroke}/>
        <rect x="-18" y="4"   width="14" height="14" rx="3" ${stroke}/>
        <rect x="6"   y="6"   width="4"  height="4"  ${stroke}/>
        <rect x="14"  y="14"  width="4"  height="4"  ${stroke}/>
      `;
    case "clock":
      return `
        <circle cx="0" cy="0" r="17" ${stroke}/>
        <line x1="0" y1="0" x2="0" y2="-10" ${stroke}/>
        <line x1="0" y1="0" x2="9" y2="4" ${stroke}/>
      `;
    case "help":
      return `
        <circle cx="0" cy="0" r="17" ${stroke}/>
        <path d="M -6 -5 Q 0 -13 6 -8 Q 10 -4 5 1 Q 0 5 0 9" ${stroke}/>
        <circle cx="0" cy="14" r="2" fill="${color}"/>
      `;
  }
  return "";
}

/**
 * Paints the gradient app background in the main content area
 * (right side of the sidebar), clipped to the screen rounded rect.
 */
export function ipadContentBackground() {
  const x = IPAD_CONTENT.x;
  const y = IPAD_CONTENT.y;
  const w = IPAD_CONTENT.w;
  const h = IPAD_CONTENT.h;
  const r = IPAD_SCREEN.radius;
  return `<path d="M ${x} ${y}
                   H ${x + w - r}
                   a ${r} ${r} 0 0 1 ${r} ${r}
                   V ${y + h - r}
                   a ${r} ${r} 0 0 1 ${-r} ${r}
                   H ${x} Z" fill="url(#ipadScreenG)"/>`;
}

export function ipadHeadline(lines, { y1 = 200, y2 = 360 } = {}) {
  return `
    <g text-anchor="middle" fill="#ffffff" font-family="${IPAD_FONT}">
      <text x="${IPAD_CANVAS.w / 2}" y="${y1}" font-size="130" font-weight="700" letter-spacing="-2">${escapeXML(lines[0])}</text>
      ${lines[1] ? `<text x="${IPAD_CANVAS.w / 2}" y="${y2}" font-size="130" font-weight="700" letter-spacing="-2" opacity="0.92">${escapeXML(lines[1])}</text>` : ""}
    </g>
  `;
}

export function ipadSubtitle(text, { y = IPAD.y + IPAD.h + 130, lineHeight = 66 } = {}) {
  const lines = Array.isArray(text) ? text : [text];
  const tspans = lines.map((line, i) =>
    `<text x="${IPAD_CANVAS.w / 2}" y="${y + i * lineHeight}" font-size="52" font-weight="500" opacity="0.95">${escapeXML(line)}</text>`
  ).join("");
  return `
    <g text-anchor="middle" font-family="${IPAD_FONT}" fill="#ffffff">
      ${tspans}
    </g>
  `;
}

export function ipadSvgShell(innerSVG) {
  return `<?xml version="1.0" encoding="UTF-8"?>
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${IPAD_CANVAS.w} ${IPAD_CANVAS.h}" width="${IPAD_CANVAS.w}" height="${IPAD_CANVAS.h}">
  <defs>${ipadDefs()}</defs>
  ${ipadBackground()}
  ${innerSVG}
</svg>
`;
}

export function escapeXML(s) {
  return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
}
