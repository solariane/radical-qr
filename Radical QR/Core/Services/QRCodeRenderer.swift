import SwiftUI
import CoreGraphics

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
        size: CGFloat
    ) -> Image? {
        guard let cgImage = renderToCGImage(
            input: input,
            configuration: configuration,
            size: size
        ) else {
            return nil
        }

        #if os(macOS)
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
        return Image(nsImage: nsImage)
        #else
        let uiImage = UIImage(cgImage: cgImage)
        return Image(uiImage: uiImage)
        #endif
    }

    /// Renders a QR code to a CGImage
    func renderToCGImage(
        input: QRInput,
        configuration: QRCodeConfiguration,
        size: CGFloat
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
        let intSize = Int(renderSize)

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
            width: intSize,
            height: intSize,
            bitsPerComponent: 8,
            bytesPerRow: intSize * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        // Enable antialiasing for smooth edges
        context.setAllowsAntialiasing(true)
        context.setShouldAntialias(true)
        context.interpolationQuality = .high

        // Flip coordinate system
        context.translateBy(x: 0, y: renderSize)
        context.scaleBy(x: 1, y: -1)

        // Draw background
        drawBackground(in: context, size: renderSize, type: configuration.backgroundType)

        // Draw QR modules with proper offset for quiet zone
        drawModules(
            in: context,
            matrix: matrix,
            moduleSize: moduleSize,
            offset: offset,
            totalSize: renderSize,
            style: configuration.foregroundStyle,
            roundness: configuration.roundness
        )

        // Draw logo if present
        if let logoData = configuration.logoData {
            drawLogo(
                in: context,
                logoData: logoData,
                size: renderSize,
                backgroundType: configuration.backgroundType
            )
        }

        // Create the high-res image and downscale for smoother result
        guard let highResImage = context.makeImage() else { return nil }
        return downsample(image: highResImage, to: Int(size))
    }

    // MARK: - Downsampling

    private func downsample(image: CGImage, to targetSize: Int) -> CGImage? {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)

        guard let context = CGContext(
            data: nil,
            width: targetSize,
            height: targetSize,
            bitsPerComponent: 8,
            bytesPerRow: targetSize * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: targetSize, height: targetSize))

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
        roundness: CGFloat
    ) {
        // Build the module path
        let modulePath = CGMutablePath()
        let cornerRadius = moduleSize * roundness * 0.5

        // Small inset to prevent touching modules from creating visual artifacts
        let inset: CGFloat = moduleSize * 0.02

        for row in 0..<matrix.size {
            for col in 0..<matrix.size {
                guard matrix.isModuleFilled(row: row, column: col) else { continue }

                let rect = CGRect(
                    x: offset + CGFloat(col) * moduleSize + inset,
                    y: offset + CGFloat(row) * moduleSize + inset,
                    width: moduleSize - (inset * 2),
                    height: moduleSize - (inset * 2)
                )

                if roundness > 0 {
                    modulePath.addRoundedRect(
                        in: rect,
                        cornerWidth: cornerRadius,
                        cornerHeight: cornerRadius
                    )
                } else {
                    modulePath.addRect(rect)
                }
            }
        }

        // Fill with the appropriate style
        context.saveGState()
        context.addPath(modulePath)
        context.clip()

        let fillRect = CGRect(origin: .zero, size: CGSize(width: totalSize, height: totalSize))

        switch style {
        case .solid(let color):
            context.setFillColor(color.cgColor)
            context.fill(fillRect)

        case .gradient(let config):
            drawGradient(in: context, config: config, size: totalSize)
        }

        context.restoreGState()
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

    private func drawLogo(
        in context: CGContext,
        logoData: Data,
        size: CGFloat,
        backgroundType: BackgroundType
    ) {
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
        // The context was flipped with translateBy(0, size) and scaleBy(1, -1)
        // We need to reverse this transformation for the logo
        context.translateBy(x: 0, y: size)
        context.scaleBy(x: 1, y: -1)

        // Now draw the logo in the un-flipped coordinate system
        // The logoRect y-coordinate needs to be adjusted for the un-flipped system
        let flippedLogoRect = CGRect(
            x: logoRect.origin.x,
            y: size - logoRect.origin.y - logoRect.height,
            width: logoRect.width,
            height: logoRect.height
        )
        context.draw(cgImage, in: flippedLogoRect)

        // Restore the flipped state for any subsequent drawing
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
        previewSize: CGFloat = 300
    ) -> Image? {
        render(input: input, configuration: configuration, size: previewSize)
    }
}
