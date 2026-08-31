import SwiftUI

/// The generator's vertical budget, in two sizes.
///
/// The screen promises that preview, settings and the save button are all
/// reachable without scrolling. One fixed set of numbers cannot keep that
/// promise: values tuned on a 874pt iPhone overflow a 667pt one by about a row
/// and a half. So the sizes come from the height actually available, measured
/// once at the root of `GeneratorView` and read from the environment by every
/// group below it.
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

    /// 700pt is above the iPhone SE's 667 and below the smallest notched phone,
    /// so the split lands where the layout actually stops fitting.
    static func fitting(height: CGFloat) -> GeneratorMetrics {
        height < 700 ? .compact : .regular
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
