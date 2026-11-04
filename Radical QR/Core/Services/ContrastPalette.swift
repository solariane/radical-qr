import Foundation

/// Keeps the generator's ready-made colours readable on a coloured background.
///
/// Contrast is the WCAG ratio (1…21) between relative luminances. Whatever the
/// background, black or white reaches at least 4.58:1 against it, so there is
/// always a side to push a colour towards: the *ink side*. Colours move along
/// lightness in OKLCH, keeping their hue — a navy that is too dark for a deep
/// green background becomes a pale blue, not a different colour.
///
/// - On a background whose ink side is dark (white, cream, yellow, a bright
///   red), the six free colours and three gradients stay, each darkened only
///   if it has to be.
/// - On a dark background they are all unreadable, so the row is drawn from
///   the background itself: white, a pale tone of its own hue, its complement,
///   and three hues spread around the wheel.
nonisolated enum ContrastPalette {
    /// Ready-made solid colours: comfortable reading.
    static let solidTarget = 4.5
    /// Gradient stops: the free gradients sit around 3:1 on white already.
    static let gradientTarget = 3.0
    /// Below this the scannability check warns.
    static let riskyContrast = 2.5

    // MARK: - Measures

    /// WCAG relative luminance, 0 (black) … 1 (white).
    static func luminance(_ color: SerializableColor) -> Double {
        0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    /// WCAG contrast ratio, 1 … 21, symmetric.
    static func contrast(_ a: SerializableColor, _ b: SerializableColor) -> Double {
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }

    /// Whether dark ink reads better than light ink on this background.
    static func inkIsDark(on background: SerializableColor) -> Bool {
        contrast(.black, background) >= contrast(.white, background)
    }

    // MARK: - Palettes

    /// The six swatches of the "Solid color" row. `nil` (white or transparent)
    /// gives the free colours untouched.
    static func solids(on background: SerializableColor?) -> [SerializableColor] {
        guard let background else { return SerializableColor.freeColors }
        if inkIsDark(on: background) {
            return SerializableColor.freeColors.map { readable($0, on: background, target: solidTarget) }
        }
        let bg = OKLCH(background)
        let hues: [Double] = bg.chroma < 0.04
            ? [110, 230, 350, 150, 300]             // grey or black: no hue to answer
            : [0, 180, 120, 240, 60].map { bg.hue + $0 }
        // Searched from the background's own lightness with the hue and chroma
        // held: going through a colour first would clamp the chroma away at a
        // lightness sRGB can't saturate (all of them, on black) and leave greys.
        let tones = hues.map { hue in
            readable(OKLCH(lightness: bg.lightness, chroma: 0.13, hue: hue), on: background, target: solidTarget)
        }
        return [.white] + tones
    }

    /// The three swatches of the "Gradient" row, same rule per stop.
    static func gradients(on background: SerializableColor?) -> [GradientConfiguration] {
        GradientConfiguration.freeGradients.map { preset in
            guard let background else { return preset }
            return readable(preset, on: background)
        }
    }

    /// `color` moved along lightness, away from the background, just far
    /// enough to reach `target`. Unchanged when it already does.
    static func readable(_ color: SerializableColor, on background: SerializableColor, target: Double) -> SerializableColor {
        if contrast(color, background) >= target { return color }
        return readable(OKLCH(color), on: background, target: target)
    }

    private static func readable(_ start: OKLCH, on background: SerializableColor, target: Double) -> SerializableColor {
        let step = inkIsDark(on: background) ? -0.005 : 0.005
        var lightness = start.lightness
        // At most 200 steps: the extreme (black or white) always clears 4.58:1.
        while (0...1).contains(lightness + step) {
            lightness += step
            let candidate = OKLCH(lightness: lightness, chroma: start.chroma, hue: start.hue).color
            if contrast(candidate, background) >= target { return candidate }
        }
        return inkIsDark(on: background) ? .black : .white
    }

    /// Both stops made readable; type and angle kept.
    static func readable(_ gradient: GradientConfiguration, on background: SerializableColor) -> GradientConfiguration {
        var result = gradient
        result.startColor = readable(gradient.startColor, on: background, target: gradientTarget)
        result.endColor = readable(gradient.endColor, on: background, target: gradientTarget)
        return result
    }

    // MARK: - sRGB ⇄ OKLCH

    private static func linear(_ c: Double) -> Double {
        let c = min(max(c, 0), 1)
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }

    fileprivate static func gamma(_ c: Double) -> Double {
        c <= 0.0031308 ? 12.92 * c : 1.055 * pow(c, 1 / 2.4) - 0.055
    }

    fileprivate static func linearRGB(_ color: SerializableColor) -> (Double, Double, Double) {
        (linear(color.red), linear(color.green), linear(color.blue))
    }
}

/// Perceptual lightness (0…1), chroma and hue (degrees).
fileprivate nonisolated struct OKLCH {
    var lightness: Double
    var chroma: Double
    var hue: Double

    init(lightness: Double, chroma: Double, hue: Double) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
    }

    init(_ color: SerializableColor) {
        let (r, g, b) = ContrastPalette.linearRGB(color)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        let okL = 0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s
        let okA = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s
        let okB = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        lightness = okL
        chroma = (okA * okA + okB * okB).squareRoot()
        hue = atan2(okB, okA) * 180 / .pi
    }

    /// The nearest displayable colour: chroma is reduced until sRGB can show it.
    var color: SerializableColor {
        var c = chroma
        for _ in 0..<40 {
            if let rgb = Self.rgb(lightness, c, hue) { return rgb }
            c *= 0.9
        }
        return Self.rgb(lightness, 0, hue) ?? .black
    }

    private static func rgb(_ L: Double, _ C: Double, _ h: Double) -> SerializableColor? {
        let a = C * cos(h * .pi / 180), b = C * sin(h * .pi / 180)
        let l = pow(L + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(L - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(L - 0.0894841775 * a - 1.2914855480 * b, 3)
        let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        let range = -0.0005...1.0005
        guard range.contains(r), range.contains(g), range.contains(bl) else { return nil }
        func encode(_ v: Double) -> Double { (ContrastPalette.gamma(min(max(v, 0), 1)) * 1000).rounded() / 1000 }
        return SerializableColor(red: encode(r), green: encode(g), blue: encode(bl))
    }
}

// MARK: - Changing the background

nonisolated extension QRCodeConfiguration {
    /// Sets the background and keeps the code readable on it.
    ///
    /// A code wearing a ready-made swatch moves to the same swatch of the new
    /// row — the selection stays where it was, in its new colour. Any other
    /// colour is kept unless it falls below the swatches' contrast, then moved
    /// only as far as it must.
    mutating func setBackground(_ type: BackgroundType, color: SerializableColor? = nil) {
        let oldFill = customBackground
        backgroundType = type
        backgroundColor = type == .white ? color : nil
        let newFill = customBackground
        guard oldFill != newFill else { return }

        switch foregroundStyle {
        case .solid(let current):
            if let index = ContrastPalette.solids(on: oldFill).firstIndex(of: current) {
                foregroundStyle = .solid(ContrastPalette.solids(on: newFill)[index])
            } else if let newFill {
                foregroundStyle = .solid(ContrastPalette.readable(current, on: newFill, target: ContrastPalette.solidTarget))
            }
        case .gradient(let current):
            if let index = ContrastPalette.gradients(on: oldFill).firstIndex(where: {
                $0.startColor == current.startColor && $0.endColor == current.endColor
            }) {
                var mapped = ContrastPalette.gradients(on: newFill)[index]
                mapped.type = current.type
                mapped.angle = current.angle
                foregroundStyle = .gradient(mapped)
            } else if let newFill {
                foregroundStyle = .gradient(ContrastPalette.readable(current, on: newFill))
            }
        }
    }

    /// The chosen colour while it is on screen; `nil` for white and transparent,
    /// which keep the free palette as it is.
    var customBackground: SerializableColor? {
        backgroundType == .white ? backgroundColor : nil
    }
}
