/**
 * screens.mjs — whole app screens, assembled once and reused per device.
 *
 * `ContentView` puts `GeneratorView` behind a `NavigationStack` on **both**
 * iPhone and iPad — the `NavigationSplitView` with a sidebar is macOS only. So
 * an iPad screenshot is the same screen as an iPhone one in a bigger box, and
 * building it twice would only be a way to get it wrong twice.
 *
 * `GeneratorView` has two arrangements, chosen by `GeneratorMetrics.layout`:
 *
 *   column — header, card, rail, panel, with the save row pinned below. Phones
 *            get it, and so does an upright iPad, capped at `contentWidth` and
 *            centred so a wide canvas widens the margins, not the card.
 *   split  — wide and short: the code and its save row on the left, the rail and
 *            the active family on the right, the pair centred in the height left
 *            under the header.
 *
 * Both are drawn here, from the same components, because both are real screens.
 * Everything is in app points; the frame scales it.
 */

import {
  METRICS, header, previewCard, familyRail, actionRow, launchCard,
  launchCardMetrics, launchWidthFor, inlineNote, recentStrip,
  shapeFamily, colorFamily, brandFamily, exportFamily, stylesFamily,
} from "./app-ui.mjs";

const FAMILY_BUILDER = {
  shape: shapeFamily, color: colorFamily, brand: brandFamily,
  export: exportFamily, styles: stylesFamily,
};

/**
 * The NavigationStack bar `ContentView` adds above the generator: no title, one
 * overflow menu. Drawn only where the device really has it.
 */
export function navBar({ x, y, width, height = 44 }) {
  const cx = x + width - 22;
  const cy = y + height / 2;
  return `<g opacity="0.95">
    <circle cx="${cx}" cy="${cy}" r="13" fill="none" stroke="#ffffff" stroke-width="1.6"/>
    ${[-5, 0, 5].map((d) => `<circle cx="${cx + d}" cy="${cy}" r="1.7" fill="#ffffff"/>`).join("")}
  </g>`;
}

/**
 * `contentColumn(width:)` — cap the column and centre what is left over.
 * Returns where the column starts and how wide it is.
 */
function column({ gutter, points, cap }) {
  const available = points.w - gutter * 2;
  const width = Math.min(available, cap);
  return { x: gutter + (available - width) / 2, width };
}

const previewCardHeight = (previewSize, m) =>
  m.cardPadding * 2 + (previewSize + 12) + m.rowGap + 30;

/**
 * The generator with content, in whichever arrangement `m.layout` calls for.
 *
 * @param {object} o
 * @param {{w: number, h: number}} o.points  Logical screen size.
 * @param {string} o.family    Which family is open.
 * @param {object} o.familyOptions  Passed through to the family builder.
 * @param {string} o.qr        Rendered code, `previewSize` across.
 */
export function generatorScreen({
  points, safeTop, safeBottom, gutter, copy, family, familyOptions = {},
  qr, previewSize, kind, content, logo = null, caption = null,
  showsNavBar = false, originX = 0, m = METRICS,
}) {
  const navH = showsNavBar ? 44 : 0;
  const { x: colX, width } = column({ gutter, points, cap: m.contentWidth });
  const headerY = safeTop + navH + m.sectionGap;
  const chrome = showsNavBar ? navBar({ x: colX, y: safeTop, width }) : "";
  const build = FAMILY_BUILDER[family];

  const body = m.layout === "split"
    ? splitBody({
        points, safeBottom, colX, width, headerY, copy, build, familyOptions,
        qr, previewSize, kind, content, logo, caption, family, m,
      })
    : columnBody({
        points, safeBottom, colX, width, headerY, copy, build, familyOptions,
        qr, previewSize, kind, content, logo, caption, family, m,
      });

  // `originX` is the macOS split view: the detail pane starts beside the
  // sidebar, and everything inside it is laid out from zero as usual.
  return `<g transform="translate(${originX} 0)">
    ${chrome}
    ${header({ x: colX, y: headerY, width, m })}
    ${body}
  </g>`;
}

/** Header, card, rail, panel — and the save row pinned to the bottom. */
function columnBody({
  points, safeBottom, colX, width, headerY, copy, build, familyOptions,
  qr, previewSize, kind, content, logo, caption, family, m,
}) {
  const previewY = headerY + m.headerHeight + m.sectionGap;
  const railY = previewY + previewCardHeight(previewSize, m) + m.sectionGap;
  const panelY = railY + m.railHeight + m.sectionGap;
  const actionY = points.h - safeBottom - m.sectionGap - m.actionHeight;

  const group = build({ x: colX, y: panelY, width, copy, m, ...familyOptions });

  return `
    ${previewCard({ x: colX, y: previewY, width, qr, previewSize, kind, content, logo, caption, m })}
    ${familyRail({ x: colX, y: railY, width, active: family, m })}
    ${group.svg}
    ${actionRow({ x: colX, y: actionY, width, label: copy.save, m })}
  `;
}

/**
 * Two columns, centred in the height under the header — the `Spacer`s either
 * side of the `HStack` in `GeneratorView.splitLayout`. The left column is a
 * fixed `previewColumn` wide; the right takes what is left.
 */
function splitBody({
  points, colX, width, headerY, copy, build, familyOptions,
  qr, previewSize, kind, content, logo, caption, family, m,
}) {
  const leftW = m.previewColumn;
  const rightX = colX + leftW + m.sectionGap;
  const rightW = width - leftW - m.sectionGap;

  const previewH = previewCardHeight(previewSize, m);
  const leftH = previewH + m.sectionGap + m.actionHeight;

  // The panel has to be measured before it can be placed, so build it at the
  // origin first and move the finished group into place.
  const probe = build({ x: 0, y: 0, width: rightW, copy, m, ...familyOptions });
  const rightH = m.railHeight + m.sectionGap + probe.height;

  const blockH = Math.max(leftH, rightH);
  const top = headerY + m.headerHeight + m.sectionGap;
  const blockY = top + Math.max(0, (points.h - m.sectionGap - top - blockH) / 2);

  const group = build({ x: rightX, y: blockY + m.railHeight + m.sectionGap, width: rightW, copy, m, ...familyOptions });

  return `
    ${previewCard({ x: colX, y: blockY, width: leftW, qr, previewSize, kind, content, logo, caption, m })}
    ${actionRow({ x: colX, y: blockY + previewH + m.sectionGap, width: leftW, label: copy.save, m })}
    ${familyRail({ x: rightX, y: blockY, width: rightW, active: family, m })}
    ${group.svg}
  `;
}

/**
 * The empty state: launch card, the Pro recents strip when there is one, then
 * the privacy note — `GeneratorView`'s own order.
 *
 * Always the column layout: `splitLayout` is only used once there is content,
 * and the card takes `launchWidth`, the narrower of the two caps.
 */
export function launchScreen({
  points, safeTop, gutter, copy, privacyNote, recents = null, recentsLabel = "Recent",
  showsNavBar = false, originX = 0, m = METRICS,
}) {
  const navH = showsNavBar ? 44 : 0;
  const { x: colX, width } = column({ gutter, points, cap: launchWidthFor(m) });
  const headerY = safeTop + navH + m.sectionGap;
  const cardY = headerY + m.headerHeight + m.sectionGap;
  const stripY = cardY + launchCardMetrics(copy, width).height + m.sectionGap;

  const strip = recents
    ? recentStrip({ x: colX, y: stripY, width, label: recentsLabel, items: recents })
    : { svg: "", height: -m.sectionGap };

  return `<g transform="translate(${originX} 0)">
    ${showsNavBar ? navBar({ x: colX, y: safeTop, width }) : ""}
    ${header({ x: colX, y: headerY, width, m })}
    ${launchCard({ x: colX, y: cardY, width, copy, m })}
    ${strip.svg}
    ${inlineNote({
      centerX: colX + width / 2,
      y: stripY + strip.height + m.sectionGap + 12,
      label: privacyNote,
    })}
  </g>`;
}
