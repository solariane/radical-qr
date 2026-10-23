import SwiftUI

/// Fades a scroll view's top or bottom edge while there is more content past
/// it. A settings panel cut off just above the save row otherwise reads as the
/// end of a card, not as "keep scrolling" — the fade says it without costing a
/// point of the vertical budget an arrow or a chevron would.
struct ScrollEdgeFade: ViewModifier {
    var length: CGFloat = 40

    @State private var edges = FadedEdges()

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 18, macOS 15, *) {
            content
                .onScrollGeometryChange(for: FadedEdges.self) { geometry in
                    // visibleRect is in content coordinates: anything above its top
                    // or below its bottom is content the user can scroll to.
                    FadedEdges(
                        top: geometry.visibleRect.minY > 1,
                        bottom: geometry.visibleRect.maxY < geometry.contentSize.height - 1
                    )
                } action: { _, newEdges in
                    withAnimation(.easeInOut(duration: 0.2)) { edges = newEdges }
                }
                .mask { fadeMask }
        } else {
            // No scroll geometry before iOS 18 / macOS 15: flashing the indicator
            // is the hint those versions get.
            content.scrollIndicatorsFlash(onAppear: true)
        }
    }

    /// Opaque everywhere except a gradient on each edge that has more content.
    /// The black overlay, not the gradient, is what animates: a faded edge is
    /// the gradient with its overlay at zero.
    private var fadeMask: some View {
        VStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                .overlay(Color.black.opacity(edges.top ? 0 : 1))
                .frame(height: length)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                .overlay(Color.black.opacity(edges.bottom ? 0 : 1))
                .frame(height: length)
        }
    }
}

/// Which edges of a scroll view have content beyond them.
private struct FadedEdges: Equatable {
    var top = false
    var bottom = false
}

extension View {
    /// Fades the top or bottom edge of a scroll view while it can scroll that way.
    func scrollEdgeFade(length: CGFloat = 40) -> some View {
        modifier(ScrollEdgeFade(length: length))
    }
}

// MARK: - Previews

#Preview("Scroll Edge Fade") {
    ZStack {
        GradientBackground()

        ScrollView {
            VStack(spacing: 12) {
                ForEach(0..<20) { index in
                    Text("Row \(index)")
                        .frame(maxWidth: .infinity)
                        .cardStyle(padding: 12)
                }
            }
            .padding()
        }
        .scrollEdgeFade()
        .frame(height: 360)
    }
}
