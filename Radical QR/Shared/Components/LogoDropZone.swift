import SwiftUI
import UniformTypeIdentifiers
import PhotosUI

/// Drop zone for adding a logo to the QR code (Pro feature)
struct LogoDropZone: View {
    @Binding var logoData: Data?
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var isTargeted = false
    @State private var showPhotoPicker = false
    @State private var showPaywall = false
    @State private var selectedPhotoItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "logo.title", defaultValue: "Logo"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if !purchaseManager.isPro {
                    ProBadge()
                }
            }

            Group {
                if purchaseManager.isPro {
                    logoContent
                } else {
                    lockedContent
                }
            }
        }
    }

    @ViewBuilder
    private var logoContent: some View {
        if let logoData, let image = platformImage(from: logoData) {
            // Show current logo
            HStack(spacing: 12) {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.secondary.opacity(0.3), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(String(localized: "logo.current", defaultValue: "Current logo"))
                        .font(.subheadline)

                    Button(role: .destructive) {
                        withAnimation {
                            self.logoData = nil
                        }
                    } label: {
                        Label(
                            String(localized: "logo.remove", defaultValue: "Remove"),
                            systemImage: "trash"
                        )
                        .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Spacer()

                Button {
                    showPhotoPicker = true
                } label: {
                    Label(
                        String(localized: "logo.change", defaultValue: "Change"),
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.secondary.opacity(0.1))
            )
        } else {
            // Drop zone
            dropZone
        }
    }

    private var dropZone: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 3])
                )
                .foregroundStyle(isTargeted ? .accent : .secondary.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isTargeted ? Color.accentColor.opacity(0.1) : Color.secondary.opacity(0.05))
                )

            VStack(spacing: 8) {
                Image(systemName: isTargeted ? "arrow.down.circle.fill" : "photo.badge.plus")
                    .font(.title2)
                    .foregroundStyle(isTargeted ? .accent : .secondary)
                    .symbolEffect(.bounce, value: isTargeted)

                Text(isTargeted
                     ? String(localized: "logo.release", defaultValue: "Release to add")
                     : String(localized: "logo.dropHint", defaultValue: "Drop image or tap to select"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: 80)
        .onDrop(of: [.image], isTargeted: $isTargeted) { providers in
            handleImageDrop(providers: providers)
        }
        .onTapGesture {
            showPhotoPicker = true
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { _, newValue in
            Task {
                await loadSelectedPhoto(newValue)
            }
        }
    }

    private var lockedContent: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(String(localized: "logo.proFeature", defaultValue: "Add your logo"))
                        .font(.subheadline.weight(.medium))

                    Text(String(localized: "logo.proHint", defaultValue: "Unlock with Pro to embed logos"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .logoEmbedding)
        }
    }

    // MARK: - Image Handling

    private func handleImageDrop(providers: [NSItemProvider]) -> Bool {
        guard purchaseManager.isPro else { return false }
        guard let provider = providers.first else { return false }

        _ = provider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, _ in
            if let data = data {
                DispatchQueue.main.async {
                    self.logoData = processImageData(data)
                }
            }
        }

        return true
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }

        do {
            if let data = try await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    self.logoData = processImageData(data)
                }
            }
        } catch {
            // Handle error silently
        }
    }

    private func processImageData(_ data: Data) -> Data? {
        // Resize image if too large (max 512x512 for logo)
        #if os(macOS)
        guard let image = NSImage(data: data) else { return nil }
        let maxSize: CGFloat = 512

        if image.size.width > maxSize || image.size.height > maxSize {
            let scale = min(maxSize / image.size.width, maxSize / image.size.height)
            let newSize = NSSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            let resizedImage = NSImage(size: newSize)
            resizedImage.lockFocus()
            image.draw(
                in: NSRect(origin: .zero, size: newSize),
                from: NSRect(origin: .zero, size: image.size),
                operation: .copy,
                fraction: 1.0
            )
            resizedImage.unlockFocus()

            return resizedImage.tiffRepresentation
        }

        return data
        #else
        guard let image = UIImage(data: data) else { return nil }
        let maxSize: CGFloat = 512

        if image.size.width > maxSize || image.size.height > maxSize {
            let scale = min(maxSize / image.size.width, maxSize / image.size.height)
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )

            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return resizedImage?.pngData()
        }

        return data
        #endif
    }

    private func platformImage(from data: Data) -> Image? {
        #if os(macOS)
        guard let nsImage = NSImage(data: data) else { return nil }
        return Image(nsImage: nsImage)
        #else
        guard let uiImage = UIImage(data: data) else { return nil }
        return Image(uiImage: uiImage)
        #endif
    }
}

// MARK: - Pro Badge

struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                Capsule()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.494, blue: 0.918),
                            Color(red: 0.463, green: 0.294, blue: 0.635)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
            )
            .foregroundStyle(.white)
    }
}

/// Button styled with Pro badge that opens paywall
struct ProBadgeButton: View {
    let feature: ProFeature
    let content: () -> any View

    @State private var showPaywall = false

    init(feature: ProFeature, @ViewBuilder content: @escaping () -> some View) {
        self.feature = feature
        self.content = content
    }

    var body: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 8) {
                AnyView(content())
                ProBadge()
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: feature)
        }
    }
}

// MARK: - Preview

#Preview("With Logo") {
    LogoDropZone(logoData: .constant(nil))
        .environmentObject(PurchaseManager.shared)
        .padding()
}

#Preview("Locked") {
    LogoDropZone(logoData: .constant(nil))
        .environmentObject(PurchaseManager.shared)
        .padding()
}
