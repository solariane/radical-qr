#if !os(macOS)
import SwiftUI
import Vision
import VisionKit

/// Apple's own scanning UI, wrapped for SwiftUI.
///
/// Live detection, so nothing is captured: the payload is read straight from the
/// video stream and the session ends. No photo is taken, none is written, and
/// the frames never leave the device — which is why the camera prompt this needs
/// can be answered honestly.
struct CodeScannerView: UIViewControllerRepresentable {
    let onFound: (String) -> Void

    /// False on devices without the required neural engine (pre-A12) and while
    /// the camera is restricted. The camera entry hides itself rather than
    /// offering something that cannot work.
    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ scanner: DataScannerViewController, context: Context) {
        guard !context.coordinator.hasFound else { return }
        try? scanner.startScanning()
    }

    static func dismantleUIViewController(_ scanner: DataScannerViewController, coordinator: Coordinator) {
        scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onFound: onFound)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onFound: (String) -> Void
        /// The scanner keeps reporting the same code every frame; take the first.
        private(set) var hasFound = false

        init(onFound: @escaping (String) -> Void) {
            self.onFound = onFound
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            handle(addedItems, in: dataScanner)
        }

        private func handle(_ items: [RecognizedItem], in scanner: DataScannerViewController) {
            guard !hasFound else { return }
            for case .barcode(let barcode) in items {
                guard let payload = barcode.payloadStringValue,
                      !payload.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
                hasFound = true
                scanner.stopScanning()
                onFound(payload)
                return
            }
        }
    }
}

/// The scanner with a way out of it, and one line saying what to do.
struct CodeScannerSheet: View {
    let onFound: (String) -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.ignoresSafeArea()

            CodeScannerView(onFound: onFound)
                .ignoresSafeArea()

            VStack {
                HStack {
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 40, height: 40)
                            .background(Circle().fill(.black.opacity(0.45)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "action.cancel", defaultValue: "Cancel"))

                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                Text(String(
                    localized: "scanner.hint",
                    defaultValue: "Point the camera at a QR code to recreate it."
                ))
                .font(.subheadline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Capsule().fill(.black.opacity(0.5)))
                .padding(.bottom, 40)
            }
        }
    }
}
#endif
