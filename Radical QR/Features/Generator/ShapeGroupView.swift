import SwiftUI

/// Shape family of the customization rail: module corners, eye shape, eye size.
///
/// These were the rows that broke on small screens — four equal-width capsules of
/// translated text turned "Rounded" into "Arron-di". Each option now draws itself,
/// so the row costs one string instead of five and cannot wrap.
struct ShapeGroupView: View {
    @Binding var configuration: QRCodeConfiguration
    let onLocked: (ProFeature) -> Void

    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.generatorMetrics) private var metrics

    private static let roundnessSteps: [CGFloat] = [0, 0.3, 0.6, 1.0]
    private static let eyeScaleSteps: [CGFloat] = [0.75, 0.9, 1.0]

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.rowGap) {
            modulesRow
            eyeStyleRow
            eyeScaleRow
        }
    }

    private var modulesRow: some View {
        VStack(alignment: .leading, spacing: metrics.labelGap) {
            SettingRowLabel(text: String(localized: "roundness.modules", defaultValue: "Modules"))

            HStack(spacing: metrics.tileGap) {
                ForEach(Self.roundnessSteps, id: \.self) { step in
                    SettingTile(
                        width: metrics.tile,
                        height: metrics.tile,
                        isSelected: matches(configuration.roundness, step),
                        label: Self.roundnessName(step),
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                configuration.roundness = step
                            }
                        }
                    ) {
                        ModuleShapeGlyph(roundness: step)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var eyeStyleRow: some View {
        VStack(alignment: .leading, spacing: metrics.labelGap) {
            SettingRowLabel(text: String(localized: "eye.style.label", defaultValue: "Eyes"))

            HStack(spacing: metrics.tileGap) {
                ForEach(QRCodeConfiguration.EyeStyle.allCases, id: \.self) { style in
                    let locked = style.isPro && !purchaseManager.isPro
                    SettingTile(
                        width: metrics.tile,
                        height: metrics.tile,
                        isSelected: configuration.eyeStyle == style,
                        isLocked: locked,
                        label: style.displayName,
                        action: {
                            if locked {
                                onLocked(.eyeStyles)
                            } else {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    configuration.eyeStyle = style
                                }
                            }
                        }
                    ) {
                        EyeShapeGlyph(style: style)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var eyeScaleRow: some View {
        VStack(alignment: .leading, spacing: metrics.labelGap) {
            SettingRowLabel(text: String(localized: "eye.size.label", defaultValue: "Eye size"))

            HStack(spacing: metrics.tileGap) {
                ForEach(Self.eyeScaleSteps, id: \.self) { step in
                    SettingTile(
                        width: metrics.tile,
                        height: metrics.tile,
                        isSelected: matches(configuration.eyeScale, step),
                        label: Self.eyeScaleName(step),
                        action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                configuration.eyeScale = step
                            }
                        }
                    ) {
                        EyeScaleGlyph(scale: step)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func matches(_ value: CGFloat, _ step: CGFloat) -> Bool {
        abs(value - step) < 0.05
    }

    // Spoken names only — nothing here is ever drawn on screen.
    private static func roundnessName(_ step: CGFloat) -> String {
        switch step {
        case 0: String(localized: "roundness.sharp", defaultValue: "Square corners", comment: "Corner shape of the QR squares: perfectly square corners, no rounding.")
        case 0.3: String(localized: "roundness.slight", defaultValue: "Slightly rounded", comment: "Corner shape of the QR squares: barely rounded corners.")
        case 0.6: String(localized: "roundness.rounded", defaultValue: "Rounded corners", comment: "Corner shape of the QR squares: clearly rounded corners.")
        default: String(localized: "roundness.circular", defaultValue: "Fully round", comment: "Corner shape of the QR squares: fully round, each square becomes a circle.")
        }
    }

    private static func eyeScaleName(_ step: CGFloat) -> String {
        switch step {
        case 0.75: String(localized: "eye.size.compact", defaultValue: "Compact", comment: "Size of the three corner markers of a QR code: the smallest of three options.")
        case 0.9: String(localized: "eye.size.medium", defaultValue: "Medium", comment: "Size of the three corner markers of a QR code: the middle of three options.")
        default: String(localized: "eye.size.full", defaultValue: "Full size", comment: "Size of the three corner markers of a QR code: the largest, filling its slot.")
        }
    }
}

#Preview("Shape group") {
    ZStack {
        GradientBackground()
        ShapeGroupView(configuration: .constant(.default), onLocked: { _ in })
            .padding(24)
    }
    .environmentObject(PurchaseManager.shared)
}
