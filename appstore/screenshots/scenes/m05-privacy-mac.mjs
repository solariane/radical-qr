/**
 * m05-privacy-mac.mjs — the reason to install this rather than paste a link into
 * a web generator. The window shows the launch screen the app really opens on,
 * and the poster's margin carries the four claims the app can keep.
 */

import { renderQR } from "../lib/qr-svg.mjs";
import { copyFor } from "../lib/copy.mjs";
import { checkList, writeScene } from "../lib/poster.mjs";
import {
  MAC_CANVAS, MAC_POINTS, MAC_DETAIL, MAC_SIDEBAR_W, MAC_GUTTER,
  macWindow, macWindowRect, macSidebar, macShell, macHeadline, macSubtitle, macSignature,
} from "../lib/mac-frame.mjs";
import { launchScreen } from "../lib/screens.mjs";
import { fittingMetrics } from "../lib/app-ui.mjs";

const LOCALE = process.argv[2] || "en-US";
const L = copyFor("privacy", LOCALE);
const LAUNCH = copyFor("launch", LOCALE);
const H = copyFor("history", LOCALE);

/** The `split` preset the Mac detail pane gets; the launch card still takes
 * `launchWidth`, so it stays a card rather than a 940pt band. */
const M = fittingMetrics(MAC_DETAIL.w, MAC_POINTS.h);

/** Narrower and pushed right, so the four claims get the left margin. */
const WIN = macWindowRect({ w: 1620, x: MAC_CANVAS.w - 1620 - 130, y: 300 });

const RECENTS = [
  { label: "radicalsolution.com", content: "https://radicalsolution.com", roundness: 0.6, eyeStyle: "leaf", eyeScale: 0.9, gradient: { start: "#4D33D9", end: "#8C3BBF", angle: 135 } },
  { label: "Wi-Fi — Studio", content: "WIFI:T:WPA;S:Studio;P:radical2026;;", roundness: 0.3, eyeStyle: "rounded", color: "#1E3A5F" },
  { label: "Nicolas Lescure", content: "BEGIN:VCARD\nVERSION:3.0\nN:Lescure;Nicolas\nEND:VCARD", roundness: 1, eyeStyle: "dot", gradient: { start: "#3B82F6", end: "#38C8D5", angle: 135 } },
  { label: "Menu — Le Verre", content: "https://leverre.example/menu", roundness: 0, eyeStyle: "square", color: "#722F37" },
];

const body = `
  ${macSidebar({ copy: L, active: "generator" })}
  ${launchScreen({
    points: { w: MAC_DETAIL.w, h: MAC_POINTS.h },
    safeTop: 10, gutter: MAC_GUTTER, originX: MAC_SIDEBAR_W,
    copy: LAUNCH, privacyNote: L.note, recentsLabel: H.recent,
    recents: RECENTS.map((item, i) => ({
      label: item.label,
      qr: renderQR({ ...item, size: 52, quietZone: 0, errorCorrection: "M", gradientId: `macRecent${i}` }),
    })),
    m: M,
  })}
`;

writeScene("m05-privacy-mac", LOCALE, macShell(`
  ${macHeadline(L.headline)}
  ${macWindow(body, WIN)}
  ${checkList(L.points, { x: 130, y: WIN.y + 210, lineHeight: 128, size: 40 })}
  ${macSubtitle(L.subtitle, { y: WIN.y + WIN.h + 110 })}
  ${macSignature(L)}
`, WIN));
