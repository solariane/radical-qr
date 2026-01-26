import SwiftUI

/// Card style modifier for consistent content cards throughout the app
struct CardStyle: ViewModifier {
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 24
    var shadowRadius: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.background)
                    .shadow(color: .black.opacity(0.1), radius: shadowRadius, y: 4)
            )
    }
}

extension View {
    /// Applies the app's card style
    func cardStyle(
        padding: CGFloat = 20,
        cornerRadius: CGFloat = 24,
        shadowRadius: CGFloat = 10
    ) -> some View {
        modifier(CardStyle(
            padding: padding,
            cornerRadius: cornerRadius,
            shadowRadius: shadowRadius
        ))
    }
}

/// Floating card style for elevated content
struct FloatingCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.15), radius: 20, y: 8)
            )
    }
}

extension View {
    /// Applies a floating card style with blur material
    func floatingCardStyle() -> some View {
        modifier(FloatingCardStyle())
    }
}

/// Section header style
struct SectionHeaderStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

extension View {
    func sectionHeaderStyle() -> some View {
        modifier(SectionHeaderStyle())
    }
}

// MARK: - Previews

#Preview("Card Style") {
    ZStack {
        GradientBackground()

        VStack {
            Text("Card Content")
                .cardStyle()
        }
        .padding()
    }
}

#Preview("Floating Card") {
    ZStack {
        GradientBackground()

        Text("Floating Content")
            .floatingCardStyle()
    }
}
