import SwiftUI

/// Vector previews for the generator's setting tiles.
///
/// Each glyph draws the *result* of its option rather than naming it, so a tile
/// needs no text: nothing to translate, nothing to truncate at 68pt wide. The
/// geometry mirrors `QRCodeRenderer` so what the tile shows is what the exporter
/// draws — a finder-pattern eye is a 7-unit square with a 1-unit ring, a 5-unit
/// cutout and a 3-unit pupil, filled even-odd.
enum QRGlyph {
    /// Ink used by every glyph. Glyphs always sit on a light tile, so this is a
    /// fixed near-black rather than a semantic color.
    static let ink = Color(red: 0.141, green: 0.122, blue: 0.192)
    static let paper = Color.white
    static let hairline = Color(red: 0.761, green: 0.745, blue: 0.824)

    /// One eye sub-rectangle in the requested style. `leaf` keeps the top-left
    /// corner sharp, matching `QRCodeRenderer.addEyeShape`.
    static func eyeShape(in rect: CGRect, style: QRCodeConfiguration.EyeStyle) -> Path {
        let r = (rect.width / 2) * style.cornerFraction
        if style.isLeaf {
            return cornerRect(rect, tl: 0, tr: r, br: r, bl: r)
        }
        guard r > 0 else { return Path(rect) }
        return Path(roundedRect: rect, cornerRadius: r)
    }

    /// Rounded rectangle with an independent radius per corner (tangent arcs, as
    /// in the renderer).
    static func cornerRect(_ rect: CGRect, tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) -> Path {
        var path = Path()
        let topL = CGPoint(x: rect.minX, y: rect.minY)
        let topR = CGPoint(x: rect.maxX, y: rect.minY)
        let botR = CGPoint(x: rect.maxX, y: rect.maxY)
        let botL = CGPoint(x: rect.minX, y: rect.maxY)
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addArc(tangent1End: topR, tangent2End: botR, radius: tr)
        path.addArc(tangent1End: botR, tangent2End: botL, radius: br)
        path.addArc(tangent1End: botL, tangent2End: topL, radius: bl)
        path.addArc(tangent1End: topL, tangent2End: topR, radius: tl)
        path.closeSubpath()
        return path
    }

    /// A whole eye — outer ring, cutout and pupil — as one even-odd path.
    static func eye(in rect: CGRect, style: QRCodeConfiguration.EyeStyle) -> Path {
        let ring = rect.width / 7
        var path = Path()
        for sub in [rect, rect.insetBy(dx: ring, dy: ring), rect.insetBy(dx: ring * 2, dy: ring * 2)]
        where sub.width > 0 {
            path.addPath(eyeShape(in: sub, style: style))
        }
        return path
    }

    /// Thumbnail shading for a foreground style. Gradient type and angle are
    /// approximated by a diagonal ramp — enough to tell two saved styles apart.
    static func shading(for style: ForegroundStyle, in size: CGSize) -> GraphicsContext.Shading {
        switch style {
        case .solid(let color):
            .color(color.color)
        case .gradient(let config):
            .linearGradient(
                Gradient(colors: [config.startColor.color, config.endColor.color]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        }
    }
}

// MARK: - Module shape

/// Six modules in a 3×3 excerpt — isolated ones and touching ones — so every
/// roundness step reads differently. A full 3×3 block would merge into one
/// square at roundness 0.
struct ModuleShapeGlyph: View {
    let roundness: CGFloat

    private static let pattern: [(col: Int, row: Int)] = [
        (0, 0), (2, 0), (0, 1), (1, 1), (1, 2), (2, 2)
    ]

    var body: some View {
        Canvas { context, size in
            let cell = size.width / 3
            for module in Self.pattern {
                let rect = CGRect(
                    x: CGFloat(module.col) * cell,
                    y: CGFloat(module.row) * cell,
                    width: cell,
                    height: cell
                )
                context.fill(
                    Path(roundedRect: rect, cornerRadius: cell / 2 * roundness),
                    with: .color(QRGlyph.ink)
                )
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Eye shape

struct EyeShapeGlyph: View {
    let style: QRCodeConfiguration.EyeStyle

    var body: some View {
        Canvas { context, size in
            context.fill(
                QRGlyph.eye(in: CGRect(origin: .zero, size: size), style: style),
                with: .color(QRGlyph.ink),
                style: FillStyle(eoFill: true)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Eye scale

/// The eye drawn inside its dashed 7×7 slot, so the option shows the *ratio*
/// rather than a percentage.
struct EyeScaleGlyph: View {
    let scale: CGFloat

    var body: some View {
        Canvas { context, size in
            let slot = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
            context.stroke(
                Path(roundedRect: slot, cornerRadius: size.width * 0.14),
                with: .color(QRGlyph.hairline),
                style: StrokeStyle(lineWidth: 1, dash: [2.5, 2])
            )
            // The real range (0.75…1.0) is only 3px wide at tile size, so the
            // glyph exaggerates it to 0.55…1.0 of the slot to stay readable.
            let drawn = min(1, max(0.2, 0.55 + (scale - 0.75) * 1.8))
            let inset = size.width * (1 - drawn * 0.82) / 2
            context.fill(
                QRGlyph.eye(in: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset), style: .rounded),
                with: .color(QRGlyph.ink),
                style: FillStyle(eoFill: true)
            )
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Background

struct BackgroundGlyph: View {
    let type: BackgroundType

    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let clip = Path(roundedRect: rect, cornerRadius: size.width * 0.22)
            context.fill(clip, with: .color(QRGlyph.paper))

            if type != .white {
                let cell = size.width / 4
                context.clip(to: clip)
                for row in 0..<4 {
                    for col in 0..<4 where (row + col).isMultiple(of: 2) {
                        context.fill(
                            Path(CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell)),
                            with: .color(QRGlyph.hairline.opacity(0.55))
                        )
                    }
                }
            }
            context.stroke(clip, with: .color(QRGlyph.hairline), lineWidth: 1)
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Caption

/// A code with, or without, the text line underneath it.
struct CaptionGlyph: View {
    let isOn: Bool

    var body: some View {
        Canvas { context, size in
            let side = isOn ? size.width * 0.82 : size.width
            let code = CGRect(x: (size.width - side) / 2, y: 0, width: side, height: side)
            context.fill(
                Path(roundedRect: code, cornerRadius: side * 0.16),
                with: .color(QRGlyph.ink)
            )
            let unit = side / 9
            for (col, row) in [(1, 1), (5, 1), (1, 5), (5, 5)] {
                context.fill(
                    Path(roundedRect: CGRect(
                        x: code.minX + CGFloat(col) * unit,
                        y: code.minY + CGFloat(row) * unit,
                        width: unit * 3,
                        height: unit * 3
                    ), cornerRadius: unit * 0.7),
                    with: .color(QRGlyph.paper)
                )
            }
            guard isOn else { return }
            let bar = CGRect(
                x: size.width * 0.1,
                y: size.height - size.height * 0.1,
                width: size.width * 0.8,
                height: size.height * 0.075
            )
            context.fill(Path(roundedRect: bar, cornerRadius: bar.height / 2), with: .color(QRGlyph.ink.opacity(0.55)))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - App mark

/// The app icon's mark — three concentric eyes and a scatter of data dots. Used
/// in the generator header so the screen carries the same identity as the icon.
struct AppMarkGlyph: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            let unit = size.width / 24
            for center in [CGPoint(x: 7, y: 7), CGPoint(x: 17, y: 7), CGPoint(x: 7, y: 17)] {
                let rect = CGRect(
                    x: (center.x - 4.6) * unit,
                    y: (center.y - 4.6) * unit,
                    width: 9.2 * unit,
                    height: 9.2 * unit
                )
                context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2.3 * unit)
            }
            let dots: [(CGFloat, CGFloat, Double)] = [
                (14.5, 14.5, 1), (19.5, 14.5, 0.6), (14.5, 19.5, 0.6), (19.5, 19.5, 1)
            ]
            for (x, y, alpha) in dots {
                let rect = CGRect(x: (x - 1.5) * unit, y: (y - 1.5) * unit, width: 3 * unit, height: 3 * unit)
                context.fill(Path(ellipseIn: rect), with: .color(color.opacity(alpha)))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Saved style thumbnail

/// A schematic code drawn with a saved style's colors, roundness and eyes — the
/// thumbnail a user recognizes their own style by. It is a fixed pattern, not the
/// real payload: generating a QR per thumbnail would cost far more than it says.
struct MiniQRGlyph: View {
    let configuration: QRCodeConfiguration

    private static let size = 21
    /// Deterministic data field with the three finder slots left clear.
    private static let modules: [[Bool]] = {
        var rows = [[Bool]]()
        var seed: UInt64 = 1_987_654_321
        func next() -> Double {
            seed = (seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407)
            return Double((seed >> 33) % 1000) / 1000
        }
        for _ in 0..<size { rows.append((0..<size).map { _ in next() < 0.47 }) }
        for (row, col) in [(0, 0), (0, size - 7), (size - 7, 0)] {
            for dy in -1..<8 {
                for dx in -1..<8 where (row + dy) >= 0 && (row + dy) < size && (col + dx) >= 0 && (col + dx) < size {
                    rows[row + dy][col + dx] = false
                }
            }
        }
        for i in 8..<(size - 8) {
            rows[6][i] = i.isMultiple(of: 2)
            rows[i][6] = i.isMultiple(of: 2)
        }
        return rows
    }()

    var body: some View {
        Canvas { context, canvasSize in
            let unit = canvasSize.width / CGFloat(Self.size)
            let shading = QRGlyph.shading(for: configuration.foregroundStyle, in: canvasSize)

            if configuration.backgroundType == .white {
                context.fill(
                    Path(roundedRect: CGRect(origin: .zero, size: canvasSize), cornerRadius: unit),
                    with: .color(QRGlyph.paper)
                )
            }

            var field = Path()
            for (row, cells) in Self.modules.enumerated() {
                for (col, on) in cells.enumerated() where on {
                    let rect = CGRect(x: CGFloat(col) * unit, y: CGFloat(row) * unit, width: unit, height: unit)
                    field.addPath(Path(roundedRect: rect, cornerRadius: unit / 2 * configuration.roundness))
                }
            }
            context.fill(field, with: shading)

            var eyes = Path()
            let span = unit * 7 * max(0.3, min(configuration.eyeScale, 1.15))
            for (row, col) in [(0, 0), (0, Self.size - 7), (Self.size - 7, 0)] {
                let slot = CGRect(x: CGFloat(col) * unit, y: CGFloat(row) * unit, width: unit * 7, height: unit * 7)
                let rect = CGRect(
                    x: slot.midX - span / 2,
                    y: slot.midY - span / 2,
                    width: span,
                    height: span
                )
                eyes.addPath(QRGlyph.eye(in: rect, style: configuration.eyeStyle))
            }
            context.fill(eyes, with: shading, style: FillStyle(eoFill: true))
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

// MARK: - Previews

#Preview("Glyphs") {
    VStack(spacing: 20) {
        HStack(spacing: 14) {
            ForEach([0, 0.3, 0.6, 1.0], id: \.self) { ModuleShapeGlyph(roundness: $0).frame(width: 34) }
        }
        HStack(spacing: 14) {
            ForEach(QRCodeConfiguration.EyeStyle.allCases, id: \.self) { EyeShapeGlyph(style: $0).frame(width: 34) }
        }
        HStack(spacing: 14) {
            ForEach([0.75, 0.9, 1.0], id: \.self) { EyeScaleGlyph(scale: $0).frame(width: 34) }
            BackgroundGlyph(type: .white).frame(width: 34)
            BackgroundGlyph(type: .transparent).frame(width: 34)
            CaptionGlyph(isOn: false).frame(width: 34)
            CaptionGlyph(isOn: true).frame(width: 34)
        }
        HStack(spacing: 14) {
            MiniQRGlyph(configuration: .default).frame(width: 52)
            MiniQRGlyph(configuration: .branded).frame(width: 52)
        }
    }
    .padding(30)
    .background(Color(white: 0.92))
}
