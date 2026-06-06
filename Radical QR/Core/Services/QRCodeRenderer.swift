import SwiftUI
import CoreGraphics
import CoreText

/// Service for rendering QR codes with custom styling (colors, gradients, roundness, logos)
final class QRCodeRenderer: Sendable {
    private let generator: QRCodeGenerator

    init(generator: QRCodeGenerator = QRCodeGenerator()) {
        self.generator = generator
    }

    /// Renders a QR code with the specified configuration
    @MainActor
    func render(
        input: QRInput,
        configuration: QRCodeConfiguration,
        size: CGFloat,
        captionText: String? = nil
    ) -> Image? {
        guard let cgImage = renderToCGImage(
            input: input,
            configuration: configuration,
            size: size,
            captionText: captionText
        ) else {
            return nil
        }

        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: imageWidth, height: imageHeight))
        return Image(nsImage: nsImage)
        #else
        let uiImage = UIImage(cgImage: cgImage)
        return Image(uiImage: uiImage)
        #endif
    }

    /// Renders a QR code to a CGImage
    /// - Parameters:
    ///   - size: The width of the QR code. If caption is provided, the height will be taller.
    ///   - captionText: Optional text to render below the QR code
    func renderToCGImage(
        input: QRInput,
        configuration: QRCodeConfiguration,
        size: CGFloat,
        captionText: String? = nil
    ) -> CGImage? {
        guard let modules = generator.extractModules(
            from: input.encodedContent,
            correctionLevel: configuration.effectiveErrorCorrectionLevel
        ),
              let matrix = QRModuleMatrix(modules: modules) else {
            return nil
        }

        // Use 2x scale for smoother rendering, then downscale
        let scale: CGFloat = 2.0
        let renderSize = size * scale

        // Calculate caption height
        let captionHeight: CGFloat = (captionText != nil)
            ? renderSize * configuration.captionSize.heightFraction
            : 0
        let totalRenderHeight = renderSize + captionHeight

        let intWidth = Int(renderSize)
        let intHeight = Int(totalRenderHeight)

        // Calculate module size with proper quiet zone (1 module padding)
        let quietZone: CGFloat = 1
        let availableSize = renderSize - (quietZone * 2 * (renderSize / CGFloat(matrix.size)))
        let moduleSize = availableSize / CGFloat(matrix.size)
        let offset = (renderSize - (moduleSize * CGFloat(matrix.size))) / 2

        // Create bitmap context with alpha
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: intWidth,
            height: intHeight,
            bitsPerComponent: 8,
            bytesPerRow: intWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Enable antialiasing for smooth edges
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high

        // Flip coordinate system (flip the entire height including caption)
        context.translateBy(x: 0, y: totalRenderHeight)
        context.scaleBy(x: 1, y: -1)

        // Draw background (only for the QR code area)
        drawBackground(in: context, size: renderSize, type: configuration.backgroundType)

        // If we have a caption area and background is white, fill caption area too
        if captionHeight > 0 && configuration.backgroundType == .white {
            let captionRect = CGRect(x: 0, y: renderSize, width: renderSize, height: captionHeight)
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(captionRect)
        }

        // Calculate logo exclusion rect if needed (for cutout mode)
        var logoExclusionRect: CGRect? = nil
        if configuration.backgroundType == .transparentWithLogoCutout,
           let logoData = configuration.logoData {
            logoExclusionRect = calculateLogoExclusionRect(
                logoData: logoData,
                renderSize: renderSize,
                moduleSize: moduleSize,
                offset: offset
            )
        }

        // Draw QR modules with proper offset for quiet zone
        drawModules(
            in: context,
            matrix: matrix,
            moduleSize: moduleSize,
            offset: offset,
            totalSize: renderSize,
            style: configuration.foregroundStyle,
            roundness: configuration.roundness,
            eyeStyle: configuration.eyeStyle,
            eyeScale: configuration.eyeScale,
            exclusionRect: logoExclusionRect
        )

        // Draw logo if present
        if let logoData = configuration.logoData {
            drawLogo(
                in: context,
                logoData: logoData,
                size: renderSize,
                backgroundType: configuration.backgroundType,
                totalHeight: totalRenderHeight
            )
        }

        // Draw caption text below QR code
        if let text = captionText {
            drawCaption(
                in: context,
                text: text,
                qrSize: renderSize,
                captionHeight: captionHeight,
                totalHeight: totalRenderHeight,
                style: configuration.foregroundStyle,
                fontSize: configuration.captionSize,
                fitToWidth: configuration.captionFitToWidth
            )
        }

        // Create the high-res image and downscale for smoother result
        guard let highResImage = context.makeImage() else { return nil }
        let targetWidth = Int(size)
        let targetHeight = Int(size + (captionText != nil ? size * configuration.captionSize.heightFraction : 0))
        return downsample(image: highResImage, toWidth: targetWidth, height: targetHeight)
    }

    // MARK: - Downsampling

    private func downsample(image: CGImage, toWidth targetWidth: Int, height targetHeight: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        return context.makeImage()
    }

    // MARK: - Private Drawing Methods

    private func drawBackground(
        in context: CGContext,
        size: CGFloat,
        type: BackgroundType
    ) {
        let rect = CGRect(origin: .zero, size: CGSize(width: size, height: size))

        switch type {
        case .white:
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            context.fill(rect)
        case .transparent, .transparentWithLogoCutout:
            // Both start with transparent background
            // Logo cutout will draw white behind logo in drawLogo
            context.clear(rect)
        }
    }

    private func drawModules(
        in context: CGContext,
        matrix: QRModuleMatrix,
        moduleSize: CGFloat,
        offset: CGFloat,
        totalSize: CGFloat,
        style: ForegroundStyle,
        roundness: CGFloat,
        eyeStyle: QRCodeConfiguration.EyeStyle,
        eyeScale: CGFloat,
        exclusionRect: CGRect? = nil
    ) {
        let cornerRadius = moduleSize * roundness * 0.5
        let inset: CGFloat = moduleSize * 0.02
        let patternSize = 7
        let size = matrix.size

        // Data modules path — skips the 7×7 finder-pattern corners (drawn separately)
        let dataPath = CGMutablePath()
        for row in 0..<size {
            for col in 0..<size {
                guard matrix.isModuleFilled(row: row, column: col) else { continue }

                // Skip any module that lives inside one of the three finder patterns.
                if isInFinderPattern(row: row, col: col, size: size, patternSize: patternSize) {
                    continue
                }

                let rect = CGRect(
                    x: offset + CGFloat(col) * moduleSize + inset,
                    y: offset + CGFloat(row) * moduleSize + inset,
                    width: moduleSize - (inset * 2),
                    height: moduleSize - (inset * 2)
                )

                if let exclusion = exclusionRect, exclusion.intersects(rect) { continue }

                if roundness > 0 {
                    dataPath.addRoundedRect(in: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
                } else {
                    dataPath.addRect(rect)
                }
            }
        }

        // Eyes path — the three finder patterns, drawn as (outer + cutout + pupil)
        // with even-odd fill so `eyeRoundness` acts independently of data roundness.
        let eyesPath = CGMutablePath()
        for region in matrix.finderPatternRegions {
            addEyeSubpath(
                to: eyesPath,
                region: region,
                moduleSize: moduleSize,
                offset: offset,
                eyeStyle: eyeStyle,
                scale: eyeScale,
                exclusionRect: exclusionRect
            )
        }

        let fillRect = CGRect(origin: .zero, size: CGSize(width: totalSize, height: totalSize))

        // Pass 1 — data modules (non-overlapping; winding fill is fine)
        context.saveGState()
        context.addPath(dataPath)
        context.clip()
        applyFill(style: style, in: context, fillRect: fillRect, size: totalSize)
        context.restoreGState()

        // Pass 2 — eyes (nested shapes; must use even-odd to carve out the ring/pupil)
        context.saveGState()
        context.addPath(eyesPath)
        context.clip(using: .evenOdd)
        applyFill(style: style, in: context, fillRect: fillRect, size: totalSize)
        context.restoreGState()
    }

    /// Returns true if the given module coordinate is inside any of the three
    /// finder-pattern (eye) regions. Uses explicit integer bounds to avoid any
    /// floating-point edge case from CGRect.contains.
    private func isInFinderPattern(row: Int, col: Int, size: Int, patternSize: Int) -> Bool {
        // Top-left
        if row < patternSize && col < patternSize { return true }
        // Top-right
        if row < patternSize && col >= size - patternSize { return true }
        // Bottom-left
        if row >= size - patternSize && col < patternSize { return true }
        return false
    }

    private func applyFill(
        style: ForegroundStyle,
        in context: CGContext,
        fillRect: CGRect,
        size: CGFloat
    ) {
        switch style {
        case .solid(let color):
            context.setFillColor(color.cgColor)
            context.fill(fillRect)
        case .gradient(let config):
            drawGradient(in: context, config: config, size: size)
        }
    }

    /// Adds a single finder-pattern eye (outer ring + inner pupil) to the given path.
    /// Even-odd fill with `outer + cutout + pupil` keeps the 1-module-thick frame
    /// AND the pupil filled while leaving the white ring between them.
    private func addEyeSubpath(
        to path: CGMutablePath,
        region: CGRect,
        moduleSize: CGFloat,
        offset: CGFloat,
        eyeStyle: QRCodeConfiguration.EyeStyle,
        scale: CGFloat,
        exclusionRect: CGRect?
    ) {
        // Full 7×7 slot, then contract around its center by (1 - scale) to shrink
        // the drawn eye while keeping it centered in the slot.
        let slotRect = CGRect(
            x: offset + region.minX * moduleSize,
            y: offset + region.minY * moduleSize,
            width: region.width * moduleSize,
            height: region.height * moduleSize
        )
        let clampedScale = max(0.3, min(scale, 1.15))
        let shrink = slotRect.width * (1 - clampedScale) / 2
        let outerRect = slotRect.insetBy(dx: shrink, dy: shrink)

        if let exclusion = exclusionRect, exclusion.intersects(outerRect) { return }

        // Ring thickness + pupil inset scale with the eye so proportions hold.
        let ringThickness = moduleSize * clampedScale
        let innerCutout = outerRect.insetBy(dx: ringThickness, dy: ringThickness)
        let pupilRect = outerRect.insetBy(dx: ringThickness * 2, dy: ringThickness * 2)

        for rect in [outerRect, innerCutout, pupilRect] where rect.width > 0 && rect.height > 0 {
            addEyeShape(to: path, rect: rect, style: eyeStyle)
        }
    }

    /// Adds one eye sub-rectangle in the requested style. `leaf` rounds three
    /// corners and leaves the top-left sharp (petal); others use a uniform radius.
    private func addEyeShape(to path: CGMutablePath, rect: CGRect, style: QRCodeConfiguration.EyeStyle) {
        let r = (rect.width / 2) * style.cornerFraction
        if style.isLeaf {
            addCornerRect(to: path, rect: rect, tl: 0, tr: r, br: r, bl: r)
        } else if r > 0 {
            path.addRoundedRect(in: rect, cornerWidth: r, cornerHeight: r)
        } else {
            path.addRect(rect)
        }
    }

    /// Rounded rectangle with an independent radius per corner. Uses tangent arcs
    /// so it is correct regardless of the (flipped) context orientation.
    private func addCornerRect(to path: CGMutablePath, rect: CGRect,
                              tl: CGFloat, tr: CGFloat, br: CGFloat, bl: CGFloat) {
        let (minX, minY, maxX, maxY) = (rect.minX, rect.minY, rect.maxX, rect.maxY)
        let topL = CGPoint(x: minX, y: minY), topR = CGPoint(x: maxX, y: minY)
        let botR = CGPoint(x: maxX, y: maxY), botL = CGPoint(x: minX, y: maxY)
        path.move(to: CGPoint(x: minX + tl, y: minY))
        path.addArc(tangent1End: topR, tangent2End: botR, radius: tr)
        path.addArc(tangent1End: botR, tangent2End: botL, radius: br)
        path.addArc(tangent1End: botL, tangent2End: topL, radius: bl)
        path.addArc(tangent1End: topL, tangent2End: topR, radius: tl)
        path.closeSubpath()
    }

    private func drawGradient(
        in context: CGContext,
        config: GradientConfiguration,
        size: CGFloat
    ) {
        let colors = [config.startColor.cgColor, config.endColor.cgColor] as CFArray
        let locations: [CGFloat] = [0, 1]

        guard let gradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: colors,
            locations: locations
        ) else { return }

        let center = CGPoint(x: size / 2, y: size / 2)

        switch config.type {
        case .linear:
            let angleRadians = config.angle * .pi / 180
            let length = size * sqrt(2)
            let dx = cos(angleRadians) * length / 2
            let dy = sin(angleRadians) * length / 2
            let start = CGPoint(x: center.x - dx, y: center.y - dy)
            let end = CGPoint(x: center.x + dx, y: center.y + dy)
            context.drawLinearGradient(gradient, start: start, end: end, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        case .radial:
            context.drawRadialGradient(
                gradient,
                startCenter: center,
                startRadius: 0,
                endCenter: center,
                endRadius: size / sqrt(2),
                options: [.drawsAfterEndLocation]
            )

        case .angular:
            drawAngularGradient(in: context, config: config, size: size)

        case .diamond:
            drawDiamondGradient(in: context, config: config, size: size)
        }
    }

    private func drawAngularGradient(
        in context: CGContext,
        config: GradientConfiguration,
        size: CGFloat
    ) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let step: CGFloat = 2 // Larger step for better performance

        for y in stride(from: 0, to: size, by: step) {
            for x in stride(from: 0, to: size, by: step) {
                let dx = x - center.x
                let dy = y - center.y
                var angle = atan2(dy, dx) + .pi
                angle = angle / (2 * .pi)

                let color = interpolateColor(
                    from: config.startColor,
                    to: config.endColor,
                    progress: angle
                )
                context.setFillColor(color)
                context.fill(CGRect(x: x, y: y, width: step, height: step))
            }
        }
    }

    private func drawDiamondGradient(
        in context: CGContext,
        config: GradientConfiguration,
        size: CGFloat
    ) {
        let center = CGPoint(x: size / 2, y: size / 2)
        let maxDistance = size / 2
        let step: CGFloat = 2

        for y in stride(from: 0, to: size, by: step) {
            for x in stride(from: 0, to: size, by: step) {
                let dx = abs(x - center.x)
                let dy = abs(y - center.y)
                let distance = (dx + dy) / maxDistance
                let progress = min(distance, 1.0)

                let color = interpolateColor(
                    from: config.startColor,
                    to: config.endColor,
                    progress: progress
                )
                context.setFillColor(color)
                context.fill(CGRect(x: x, y: y, width: step, height: step))
            }
        }
    }

    private func interpolateColor(
        from start: SerializableColor,
        to end: SerializableColor,
        progress: CGFloat
    ) -> CGColor {
        let r = start.red + (end.red - start.red) * progress
        let g = start.green + (end.green - start.green) * progress
        let b = start.blue + (end.blue - start.blue) * progress
        let a = start.opacity + (end.opacity - start.opacity) * progress
        return CGColor(red: r, green: g, blue: b, alpha: a)
    }

    /// Calculates the exclusion rect for logo cutout (the area where QR modules should not be drawn)
    private func calculateLogoExclusionRect(
        logoData: Data,
        renderSize: CGFloat,
        moduleSize: CGFloat,
        offset: CGFloat
    ) -> CGRect {
        #if os(macOS)
        let imageSize: CGSize
        if let nsImage = NSImage(data: logoData) {
            imageSize = nsImage.size
        } else {
            imageSize = CGSize(width: 100, height: 100)
        }
        #else
        let imageSize: CGSize
        if let uiImage = UIImage(data: logoData) {
            imageSize = uiImage.size
        } else {
            imageSize = CGSize(width: 100, height: 100)
        }
        #endif

        let aspectRatio = imageSize.width / imageSize.height
        let maxLogoSize = renderSize * 0.25

        let logoWidth: CGFloat
        let logoHeight: CGFloat

        if aspectRatio > 1 {
            logoWidth = maxLogoSize
            logoHeight = maxLogoSize / aspectRatio
        } else {
            logoHeight = maxLogoSize
            logoWidth = maxLogoSize * aspectRatio
        }

        // Use the larger dimension to make a SQUARE cutout
        let cutoutBase = max(logoWidth, logoHeight)
        let padding = cutoutBase * 0.12
        let cutoutSize = cutoutBase + padding * 2

        // Return a centered square exclusion rect
        return CGRect(
            x: (renderSize - cutoutSize) / 2,
            y: (renderSize - cutoutSize) / 2,
            width: cutoutSize,
            height: cutoutSize
        )
    }

    private func drawLogo(
        in context: CGContext,
        logoData: Data,
        size: CGFloat,
        backgroundType: BackgroundType,
        totalHeight: CGFloat? = nil
    ) {
        let canvasHeight = totalHeight ?? size
        #if os(macOS)
        guard let nsImage = NSImage(data: logoData),
              let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return
        }
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)
        #else
        guard let uiImage = UIImage(data: logoData),
              let cgImage = uiImage.cgImage else {
            return
        }
        let imageWidth = uiImage.size.width
        let imageHeight = uiImage.size.height
        #endif

        // Calculate logo placement (centered, ~25% of QR code size)
        // Preserve original aspect ratio
        let maxLogoSize = size * 0.25
        let aspectRatio = imageWidth / imageHeight

        let logoWidth: CGFloat
        let logoHeight: CGFloat

        if aspectRatio > 1 {
            // Wider than tall
            logoWidth = maxLogoSize
            logoHeight = maxLogoSize / aspectRatio
        } else {
            // Taller than wide (or square)
            logoHeight = maxLogoSize
            logoWidth = maxLogoSize * aspectRatio
        }

        let logoRect = CGRect(
            x: (size - logoWidth) / 2,
            y: (size - logoHeight) / 2,
            width: logoWidth,
            height: logoHeight
        )

        // Draw white background behind logo only for .white background type
        // - white: draw white background for logo visibility
        // - transparent: no background (preserve logo transparency)
        // - transparentWithLogoCutout: transparent cutout (no white, just the logo)
        if backgroundType == .white {
            let padding: CGFloat = min(logoWidth, logoHeight) * 0.12
            let backgroundRect = logoRect.insetBy(dx: -padding, dy: -padding)
            context.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))

            let cornerRadius = padding * 0.8
            let backgroundPath = CGPath(
                roundedRect: backgroundRect,
                cornerWidth: cornerRadius,
                cornerHeight: cornerRadius,
                transform: nil
            )
            context.addPath(backgroundPath)
            context.fillPath()
        }

        // Save the current graphics state (which has flipped coordinates)
        context.saveGState()

        // Un-flip the coordinate system for drawing the logo correctly
        // The context was flipped with translateBy(0, canvasHeight) and scaleBy(1, -1)
        // We need to reverse this transformation for the logo
        context.translateBy(x: 0, y: canvasHeight)
        context.scaleBy(x: 1, y: -1)

        // Now draw the logo in the un-flipped coordinate system
        // The logoRect y-coordinate needs to be adjusted for the un-flipped system
        let flippedLogoRect = CGRect(
            x: logoRect.origin.x,
            y: canvasHeight - logoRect.origin.y - logoRect.height,
            width: logoRect.width,
            height: logoRect.height
        )
        context.draw(cgImage, in: flippedLogoRect)

        // Restore the flipped state for any subsequent drawing
        context.restoreGState()
    }

    // MARK: - Caption Drawing

    private func drawCaption(
        in context: CGContext,
        text: String,
        qrSize: CGFloat,
        captionHeight: CGFloat,
        totalHeight: CGFloat,
        style: ForegroundStyle,
        fontSize: QRCodeConfiguration.CaptionSize,
        fitToWidth: Bool
    ) {
        let baseFontSize = qrSize * fontSize.relativeFraction
        let maxWidth = qrSize * 0.9

        let color: CGColor
        switch style {
        case .solid(let c):
            color = c.cgColor
        case .gradient(let g):
            // Use the start color of the gradient for the caption
            color = g.startColor.cgColor
        }

        // Measure at the base size to decide whether to shrink (fit) or truncate.
        let baseFont = CTFontCreateWithName("Helvetica" as CFString, baseFontSize, nil)
        let measuredWidth = CTLineGetBoundsWithOptions(
            CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: baseFont])),
            .useOpticalBounds
        ).width

        // Fit mode: scale the font down so the whole string fits (never up).
        let fontSizePoints = (fitToWidth && measuredWidth > maxWidth)
            ? baseFontSize * (maxWidth / measuredWidth)
            : baseFontSize
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSizePoints, nil)

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: color
        ]
        let attrString = NSAttributedString(string: text, attributes: attributes)
        let line = CTLineCreateWithAttributedString(attrString)
        let lineRect = CTLineGetBoundsWithOptions(line, .useOpticalBounds)

        // Truncate only when NOT fitting to width and the text overflows.
        let displayLine: CTLine
        if !fitToWidth && lineRect.width > maxWidth {
            let truncationToken = NSAttributedString(string: "...", attributes: attributes)
            let tokenLine = CTLineCreateWithAttributedString(truncationToken)
            if let truncated = CTLineCreateTruncatedLine(line, maxWidth, .end, tokenLine) {
                displayLine = truncated
            } else {
                displayLine = line
            }
        } else {
            displayLine = line
        }

        let displayRect = CTLineGetBoundsWithOptions(displayLine, .useOpticalBounds)

        // Center horizontally, position in caption area below QR code
        let x = (qrSize - displayRect.width) / 2 - displayRect.origin.x
        let captionAreaY = qrSize
        let y = captionAreaY + (captionHeight - displayRect.height) / 2

        // CoreText uses unflipped coordinates, but our context is flipped.
        // We need to un-flip for text drawing.
        context.saveGState()
        context.translateBy(x: 0, y: totalHeight)
        context.scaleBy(x: 1, y: -1)

        // In unflipped coordinates, the caption area is at the bottom (lower y values)
        let unflippedY = totalHeight - y - displayRect.height - displayRect.origin.y
        context.textPosition = CGPoint(x: x, y: unflippedY)
        CTLineDraw(displayLine, context)

        context.restoreGState()
    }
}

// MARK: - Preview Helper

extension QRCodeRenderer {
    /// Generates a preview image at a standard size
    @MainActor
    func preview(
        input: QRInput,
        configuration: QRCodeConfiguration,
        previewSize: CGFloat = 300,
        captionText: String? = nil
    ) -> Image? {
        render(input: input, configuration: configuration, size: previewSize, captionText: captionText)
    }
}
