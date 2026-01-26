import SwiftUI

/// The app's signature gradient background matching the web service
struct GradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.4, green: 0.494, blue: 0.918),    // #667eea
                Color(red: 0.463, green: 0.294, blue: 0.635)   // #764ba2
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

/// A subtle animated version of the gradient background
struct AnimatedGradientBackground: View {
    @State private var animateGradient = false

    var body: some View {
        LinearGradient(
            colors: animateGradient ? [
                Color(red: 0.463, green: 0.294, blue: 0.635),
                Color(red: 0.4, green: 0.494, blue: 0.918)
            ] : [
                Color(red: 0.4, green: 0.494, blue: 0.918),
                Color(red: 0.463, green: 0.294, blue: 0.635)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 5).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

#Preview("Gradient Background") {
    GradientBackground()
}

#Preview("Animated Gradient") {
    AnimatedGradientBackground()
}
