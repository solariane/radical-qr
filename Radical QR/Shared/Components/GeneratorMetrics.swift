import SwiftUI

/// How the generator arranges its blocks for the canvas it was given.
enum GeneratorLayout: Equatable, Sendable {
    /// One column — header, card, rail, panel — with the save row pinned below.
    case column
    /// Preview and save row on the left, rail and panel on the right. For a
    /// canvas with width to spare and no height to spare.
    case split
}

/// The generator's layout budget, in four sizes.
///
/// The screen promises that preview, settings and the save button are all
/// reachable without scrolling. One fixed set of numbers cannot keep that
/// promise: values tuned on a 874pt iPhone overflow a 667pt one by about a row
/// and a half, and leave an iPad ending in bare gradient. So the sizes — and
/// the arrangement — come from the size actually available, measured once at
/// the root of `GeneratorView` and read from the environment by every group
/// below it.
struct GeneratorMetrics: Equatable, Sendable {
    /// Longest side of the QR preview.
    var preview: CGFloat
    /// Square tile for shapes, eyes, caption.
    var tile: CGFloat
    /// Smaller round tile for colors and saved styles, which come six to a row.
    var swatch: CGFloat
    /// Rectangular tile for a number or a format acronym.
    var tokenWidth: CGFloat
    var tokenHeight: CGFloat
    /// Between tiles in a row.
    var tileGap: CGFloat
    /// Between a row's label and its tiles.
    var labelGap: CGFloat
    /// Between rows inside one family.
    var rowGap: CGFloat
    /// Between the screen's blocks: header, card, rail, panel, actions.
    var sectionGap: CGFloat
    var panelPadding: CGFloat
    var cardPadding: CGFloat
    var railHeight: CGFloat
    var actionHeight: CGFloat
    var headerHeight: CGFloat
    /// Widest the content block gets. A phone fills its screen; a regular-width
    /// canvas centers a column instead of stretching one card across 992pt.
    var contentWidth: CGFloat = .infinity
    /// In `.split`, the width of the column holding the preview and save row.
    /// The other column takes what is left.
    var previewColumn: CGFloat = 0
    var layout: GeneratorLayout = .column

    /// The launch screen is one card and a sentence. On a canvas wide enough to
    /// have a cap at all, it takes the narrower of the two — an iPad on its side
    /// should not stretch a drop target across 940pt.
    var launchWidth: CGFloat { contentWidth.isFinite ? min(contentWidth, 640) : contentWidth }

    static let regular = GeneratorMetrics(
        preview: 186, tile: 48, swatch: 44,
        tokenWidth: 72, tokenHeight: 48,
        tileGap: 10, labelGap: 5, rowGap: 10, sectionGap: 11,
        panelPadding: 12, cardPadding: 14,
        railHeight: 46, actionHeight: 54, headerHeight: 30
    )

    /// Short screens — iPhone SE and 8, and any window squeezed to that height.
    /// The preview gives up the most, because it is the one element that stays
    /// legible when it shrinks.
    static let compact = GeneratorMetrics(
        preview: 140, tile: 44, swatch: 40,
        tokenWidth: 64, tokenHeight: 42,
        tileGap: 8, labelGap: 3, rowGap: 7, sectionGap: 8,
        panelPadding: 10, cardPadding: 11,
        railHeight: 42, actionHeight: 48, headerHeight: 28
    )

    /// A canvas that is both wide and tall — an iPad held upright, or a Mac
    /// window taller than it is wide. Everything grows; the column is capped so
    /// the card stays a card rather than a band.
    static let expanded = GeneratorMetrics(
        preview: 360, tile: 64, swatch: 58,
        tokenWidth: 94, tokenHeight: 60,
        tileGap: 14, labelGap: 7, rowGap: 15, sectionGap: 17,
        panelPadding: 18, cardPadding: 19,
        railHeight: 60, actionHeight: 62, headerHeight: 34,
        contentWidth: 640
    )

    /// Wide and short — an iPad on its side, a Mac window dragged out. Here the
    /// single column is the wrong shape twice over: it would start scrolling
    /// while leaving two thirds of the width unused. The settings move beside
    /// the code instead.
    static let split = GeneratorMetrics(
        preview: 300, tile: 60, swatch: 54,
        tokenWidth: 86, tokenHeight: 56,
        tileGap: 12, labelGap: 6, rowGap: 13, sectionGap: 15,
        panelPadding: 16, cardPadding: 17,
        railHeight: 56, actionHeight: 58, headerHeight: 32,
        contentWidth: 940, previewColumn: 358, layout: .split
    )

    /// 700pt is above the iPhone SE's 667 and below the smallest notched phone,
    /// so the phone split lands where the layout actually stops fitting. The
    /// same number as a width floor keeps an iPad in a narrow Split View — which
    /// really is phone-shaped — on the phone layout.
    static func fitting(width: CGFloat, height: CGFloat) -> GeneratorMetrics {
        guard width >= 700, height >= 700 else {
            return height < 700 ? .compact : .regular
        }

        if height >= width {
            var metrics = expanded
            // Slack above the shortest iPad portrait goes to the preview: it is
            // the one block that only improves as it grows, and spending it
            // there is what keeps a 13" screen from ending in bare gradient.
            metrics.preview = min(480, metrics.preview + max(0, height - 1080) * 0.55)
            return metrics
        }

        var metrics = split
        metrics.preview = min(420, metrics.preview + max(0, height - 760) * 0.45)
        metrics.previewColumn = metrics.preview + metrics.cardPadding * 2 + 24
        return metrics
    }
}

private struct GeneratorMetricsKey: EnvironmentKey {
    static let defaultValue = GeneratorMetrics.regular
}

extension EnvironmentValues {
    var generatorMetrics: GeneratorMetrics {
        get { self[GeneratorMetricsKey.self] }
        set { self[GeneratorMetricsKey.self] = newValue }
    }
}

extension View {
    /// Caps the content at `width` and centers what is left over. `.infinity`
    /// leaves it alone, which is what a phone wants.
    func contentColumn(width: CGFloat) -> some View {
        frame(maxWidth: width).frame(maxWidth: .infinity)
    }
}
