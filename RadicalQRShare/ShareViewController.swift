import SwiftUI

#if os(macOS)
import AppKit

class ShareViewController: NSViewController {
    private var hostingController: NSHostingController<ShareExtensionView>?

    override func loadView() {
        // NSViewController requires self.view to be set in loadView()
        // when not using a storyboard/nib. Provide a concrete frame so
        // the SwiftUI hosting controller has something to lay out against.
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 340, height: 480))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let hc = NSHostingController(
            rootView: ShareExtensionView(
                extensionContext: extensionContext,
                openURL: { [weak self] url in
                    self?.openURLInHostApp(url)
                }
            )
        )
        hostingController = hc

        addChild(hc)
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hc.view)

        NSLayoutConstraint.activate([
            hc.view.topAnchor.constraint(equalTo: view.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hc.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        self.preferredContentSize = NSSize(width: 340, height: 480)
    }

    private func openURLInHostApp(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}

#else
import UIKit

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        let hostingController = UIHostingController(
            rootView: ShareExtensionView(
                extensionContext: extensionContext
            )
        )

        addChild(hostingController)
        view.addSubview(hostingController.view)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])

        hostingController.didMove(toParent: self)
    }
}
#endif
