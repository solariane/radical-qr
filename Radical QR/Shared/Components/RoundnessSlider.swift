import SwiftUI

/// Slider for adjusting QR code module roundness
struct RoundnessSlider: View {
    @Binding var roundness: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "roundness.title", defaultValue: "Roundness"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(roundness * 100))%")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                // Sharp icon
                RoundnessIcon(roundness: 0)
                    .opacity(roundness < 0.5 ? 1 : 0.4)

                // Slider
                Slider(value: $roundness, in: 0...1)
                    .tint(Color.accentColor)

                // Round icon
                RoundnessIcon(roundness: 1)
                    .opacity(roundness >= 0.5 ? 1 : 0.4)
            }

            // Quick presets
            HStack(spacing: 8) {
                RoundnessPresetButton(label: String(localized: "roundness.sharp", defaultValue: "Sharp"), value: 0, current: $roundness)
                RoundnessPresetButton(label: String(localized: "roundness.slight", defaultValue: "Slight"), value: 0.3, current: $roundness)
                RoundnessPresetButton(label: String(localized: "roundness.rounded", defaultValue: "Rounded"), value: 0.6, current: $roundness)
                RoundnessPresetButton(label: String(localized: "roundness.circular", defaultValue: "Circular"), value: 1.0, current: $roundness)
            }
        }
    }
}

/// Visual representation of roundness level
struct RoundnessIcon: View {
    let roundness: CGFloat

    var body: some View {
        Grid(horizontalSpacing: 2, verticalSpacing: 2) {
            GridRow {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(width: 8, height: 8)
            }
            GridRow {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(width: 8, height: 8)
                RoundedRectangle(cornerRadius: cornerRadius)
                    .frame(width: 8, height: 8)
            }
        }
        .foregroundStyle(.primary)
    }

    private var cornerRadius: CGFloat {
        4 * roundness
    }
}

/// Preset button for quick roundness selection
struct RoundnessPresetButton: View {
    let label: String
    let value: CGFloat
    @Binding var current: CGFloat

    private var isSelected: Bool {
        abs(current - value) < 0.05
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                current = value
            }
        } label: {
            Text(label)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                )
                .overlay(
                    Capsule()
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isSelected ? .primary : .secondary)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        RoundnessSlider(roundness: .constant(0.5))
    }
    .padding()
}
