import SwiftUI
import UniformTypeIdentifiers

/// Export options sheet
struct ExportView: View {
    @ObservedObject var viewModel: GeneratorViewModel
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedFormat: ExportFormat = .png
    @State private var selectedSize: ExportSize = .medium
    @State private var isExporting = false
    @State private var exportError: Error?
    @State private var showShareSheet = false
    @State private var exportedFileURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Preview
                    previewSection

                    // Format selection
                    formatSection

                    // Size selection
                    sizeSection

                    // Export buttons
                    exportActions
                }
                .padding()
            }
            #if os(iOS)
            .background(Color(.systemGroupedBackground))
            #endif
            .navigationTitle(String(localized: "export.title", defaultValue: "Export"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "action.cancel", defaultValue: "Cancel")) {
                        dismiss()
                    }
                }
            }
            .alert(
                String(localized: "error.title", defaultValue: "Error"),
                isPresented: .init(
                    get: { exportError != nil },
                    set: { if !$0 { exportError = nil } }
                )
            ) {
                Button(String(localized: "error.dismiss", defaultValue: "OK")) {
                    exportError = nil
                }
            } message: {
                if let error = exportError {
                    Text(error.localizedDescription)
                }
            }
            #if os(iOS)
            .sheet(isPresented: $showShareSheet) {
                if let url = exportedFileURL {
                    ShareSheet(items: [url])
                }
            }
            #endif
        }
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        VStack(spacing: 12) {
            if let image = viewModel.previewImage {
                image
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 200)
                    .background(
                        CheckerboardPattern()
                            .opacity(viewModel.configuration.backgroundType == .transparent ? 1 : 0)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.secondary.opacity(0.2), lineWidth: 1)
                    )
            }

            // Detected type badge
            HStack(spacing: 6) {
                Image(systemName: viewModel.detectedDataType.iconName)
                Text(viewModel.detectedDataType.displayName)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
        )
    }

    // MARK: - Format Section

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "export.format", defaultValue: "Format"))
                .sectionHeaderStyle()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(ExportFormat.allCases) { format in
                    FormatButton(
                        format: format,
                        isSelected: selectedFormat == format,
                        isLocked: format.requiresPro && !purchaseManager.isPro
                    ) {
                        selectedFormat = format
                    }
                }
            }
        }
    }

    // MARK: - Size Section

    private var sizeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(String(localized: "export.size", defaultValue: "Size"))
                    .sectionHeaderStyle()

                Spacer()

                if !purchaseManager.isPro {
                    Text(String(localized: "export.sizeLimit", defaultValue: "Max \(FeatureLimit.freeMaxExportSize)px free"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(ExportSize.allSizes, id: \.width) { size in
                    SizeButton(
                        size: size,
                        isSelected: selectedSize == size,
                        isLocked: !purchaseManager.isExportSizeAvailable(size)
                    ) {
                        selectedSize = size
                    }
                }
            }
        }
    }

    // MARK: - Export Actions

    private var exportActions: some View {
        VStack(spacing: 12) {
            // Primary export button
            Button {
                Task {
                    await performExport()
                }
            } label: {
                HStack {
                    if isExporting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "square.and.arrow.down")
                    }

                    Text(String(localized: "export.save", defaultValue: "Save"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(isExporting || !canExport)

            // Share button
            Button {
                Task {
                    await performShare()
                }
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(String(localized: "export.share", defaultValue: "Share"))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(isExporting || !canExport)
        }
    }

    // MARK: - Helpers

    private var canExport: Bool {
        guard viewModel.hasValidInput else { return false }

        if selectedFormat.requiresPro && !purchaseManager.isPro {
            return false
        }

        if !purchaseManager.isExportSizeAvailable(selectedSize) {
            return false
        }

        return true
    }

    private var exportConfiguration: ExportConfiguration {
        ExportConfiguration(
            format: selectedFormat,
            size: selectedSize,
            includeBackground: viewModel.configuration.backgroundType == .white
        )
    }

    private func performExport() async {
        isExporting = true

        do {
            let url = try await viewModel.saveToFile(config: exportConfiguration)

            #if os(macOS)
            // On macOS, reveal in Finder
            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: "")
            dismiss()
            #else
            // On iOS, show save dialog
            exportedFileURL = url
            showShareSheet = true
            #endif
        } catch {
            exportError = error
        }

        isExporting = false
    }

    private func performShare() async {
        isExporting = true

        do {
            let url = try await viewModel.saveToFile(config: exportConfiguration)
            exportedFileURL = url
            showShareSheet = true
        } catch {
            exportError = error
        }

        isExporting = false
    }
}

// MARK: - Format Button

struct FormatButton: View {
    let format: ExportFormat
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
                ZStack(alignment: .topTrailing) {
                    Text(format.displayName)
                        .font(.headline)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .offset(x: 8, y: -4)
                    }
                }

                if format.isVector {
                    Text(String(localized: "format.vector", defaultValue: "Vector"))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isLocked ? .secondary : (isSelected ? .primary : .secondary))
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .svgExport)
        }
    }
}

// MARK: - Size Button

struct SizeButton: View {
    let size: ExportSize
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
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Text(size.displayName)
                        .font(.subheadline.monospacedDigit())

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .offset(x: 8, y: -4)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .foregroundStyle(isLocked ? .secondary : (isSelected ? .primary : .secondary))
        .sheet(isPresented: $showPaywall) {
            PaywallView(feature: .unlimitedExportSize)
        }
    }
}

// MARK: - Share Sheet (iOS)

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

// MARK: - Preview

#Preview {
    ExportView(viewModel: GeneratorViewModel())
        .environmentObject(PurchaseManager.shared)
}
