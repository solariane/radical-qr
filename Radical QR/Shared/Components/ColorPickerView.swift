import SwiftUI

/// Custom color picker with preset colors and optional full picker for Pro users
struct ColorPickerView: View {
    @Binding var selectedColor: SerializableColor
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var showFullPicker = false

    private let presetColors = SerializableColor.freeColors

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "colorPicker.title", defaultValue: "Color"))
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            // Preset colors grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                ForEach(presetColors, id: \.self) { color in
                    ColorSwatch(
                        color: color,
                        isSelected: selectedColor == color
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedColor = color
                        }
                    }
                }
            }

            // Custom color button (Pro)
            if purchaseManager.isPro {
                HStack {
                    ColorPicker(
                        String(localized: "colorPicker.custom", defaultValue: "Custom color"),
                        selection: Binding(
                            get: { selectedColor.color },
                            set: { selectedColor = SerializableColor($0) }
                        ),
                        supportsOpacity: false
                    )
                    .labelsHidden()

                    Text(String(localized: "colorPicker.custom", defaultValue: "Custom color"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer()
                }
                .padding(.top, 4)
            } else {
                ProBadgeButton(feature: .fullColorPicker) {
                    HStack {
                        Image(systemName: "paintpalette")
                        Text(String(localized: "colorPicker.unlockCustom", defaultValue: "Unlock custom colors"))
                    }
                }
            }
        }
    }
}

/// Individual color swatch button
struct ColorSwatch: View {
    let color: SerializableColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.color)
                    .shadow(color: color.color.opacity(0.4), radius: isSelected ? 4 : 0, y: 2)

                if isSelected {
                    Circle()
                        .strokeBorder(.white, lineWidth: 3)

                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .shadow(radius: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// MARK: - Gradient Color Picker

struct GradientColorPickerView: View {
    @Binding var gradient: GradientConfiguration
    @EnvironmentObject private var purchaseManager: PurchaseManager

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Gradient type selector
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "gradientPicker.type", defaultValue: "Gradient Type"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(GradientConfiguration.GradientType.allCases, id: \.self) { type in
                        GradientTypeButton(
                            type: type,
                            isSelected: gradient.type == type,
                            isLocked: !purchaseManager.isPro && !isFreeGradientType(type)
                        ) {
                            withAnimation {
                                gradient.type = type
                            }
                        }
                    }
                }
            }

            // Start color
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "gradientPicker.startColor", defaultValue: "Start Color"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                GradientColorRow(color: $gradient.startColor)
            }

            // End color
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "gradientPicker.endColor", defaultValue: "End Color"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                GradientColorRow(color: $gradient.endColor)
            }

            // Angle slider (for linear gradient)
            if gradient.type == .linear {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(String(localized: "gradientPicker.angle", defaultValue: "Angle"))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)

                        Spacer()

                        Text("\(Int(gradient.angle))°")
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $gradient.angle, in: 0...360, step: 15)
                        .tint(gradient.startColor.color)
                }
            }
        }
    }

    private func isFreeGradientType(_ type: GradientConfiguration.GradientType) -> Bool {
        type == .linear || type == .radial
    }
}

/// Row for selecting a gradient color
struct GradientColorRow: View {
    @Binding var color: SerializableColor
    @EnvironmentObject private var purchaseManager: PurchaseManager

    private let presetColors = SerializableColor.freeColors

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(presetColors, id: \.self) { presetColor in
                    ColorSwatch(
                        color: presetColor,
                        isSelected: color == presetColor
                    ) {
                        color = presetColor
                    }
                    .frame(width: 36, height: 36)
                }

                if purchaseManager.isPro {
                    ColorPicker("", selection: Binding(
                        get: { color.color },
                        set: { color = SerializableColor($0) }
                    ), supportsOpacity: false)
                    .labelsHidden()
                    .frame(width: 36, height: 36)
                }
            }
        }
    }
}

/// Button for selecting gradient type
struct GradientTypeButton: View {
    let type: GradientConfiguration.GradientType
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    @State private var showPaywall = false

    var body: some View {
        Button {
            if isLocked {
                showPaywall = true
            } else {
                action()
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Image(systemName: type.iconName)
                        .font(.title3)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .offset(x: 10, y: -8)
                    }
                }

                Text(type.displayName)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isLocked ? .secondary : (isSelected ? .primary : .secondary))
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .allGradientTypes)
        }
    }
}

// MARK: - Previews

#Preview("Color Picker") {
    ColorPickerView(selectedColor: .constant(.indigo))
        .environmentObject(PurchaseManager.shared)
        .padding()
}

#Preview("Gradient Picker") {
    GradientColorPickerView(gradient: .constant(.purpleViolet))
        .environmentObject(PurchaseManager.shared)
        .padding()
}
