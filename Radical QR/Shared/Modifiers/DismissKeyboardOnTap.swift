#if os(iOS)
import SwiftUI
import UIKit

extension View {
    /// Tapping anywhere outside a text field puts the keyboard away.
    ///
    /// Not `.onTapGesture` on the screen: since iOS 18 a SwiftUI gesture is a
    /// UIKit recognizer, and one on an ancestor cancels the touches of the UIKit
    /// controls underneath. The system `PasteButton` is such a control — it lit
    /// up when there was something to paste and did nothing when tapped. This
    /// recognizer sits on the window, cancels nothing, and ignores taps that land
    /// on a field or a control.
    func dismissesKeyboardOnTap() -> some View {
        background(KeyboardDismissInstaller().allowsHitTesting(false))
    }
}

private struct KeyboardDismissInstaller: UIViewRepresentable {
    func makeUIView(context: Context) -> InstallerView { InstallerView() }
    func updateUIView(_ uiView: InstallerView, context: Context) {}

    final class InstallerView: UIView, UIGestureRecognizerDelegate {
        private lazy var tap: UITapGestureRecognizer = {
            let tap = UITapGestureRecognizer(target: self, action: #selector(dismiss))
            tap.cancelsTouchesInView = false
            tap.delegate = self
            return tap
        }()

        override func didMoveToWindow() {
            super.didMoveToWindow()
            tap.view?.removeGestureRecognizer(tap)
            window?.addGestureRecognizer(tap)
        }

        @objc private func dismiss() {
            window?.endEditing(false)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            var view = touch.view
            while let current = view {
                if current is UITextField || current is UITextView || current is UIControl { return false }
                view = current.superview
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}
#endif
