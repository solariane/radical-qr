import SwiftUI
import SwiftData

/// History view showing saved QR codes (Pro feature)
struct HistoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @Query(sort: \HistoryItem.lastUsedAt, order: .reverse)
    private var historyItems: [HistoryItem]

    @State private var searchText = ""
    @State private var selectedItem: HistoryItem?
    @State private var showDeleteConfirmation = false
    @State private var itemToDelete: HistoryItem?

    private var filteredItems: [HistoryItem] {
        guard !searchText.isEmpty else { return historyItems }

        return historyItems.filter { item in
            item.content.localizedCaseInsensitiveContains(searchText) ||
            item.title?.localizedCaseInsensitiveContains(searchText) == true
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if historyItems.isEmpty {
                    emptyState
                } else {
                    historyList
                }
            }
            .navigationTitle(String(localized: "history.title", defaultValue: "History"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                    }
                }
                #endif

                if !historyItems.isEmpty {
                    ToolbarItem(placement: .destructiveAction) {
                        Menu {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label(
                                    String(localized: "history.clearAll", defaultValue: "Clear All"),
                                    systemImage: "trash"
                                )
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .searchable(
                text: $searchText,
                prompt: String(localized: "history.search", defaultValue: "Search history")
            )
            .alert(
                String(localized: "history.clearConfirm.title", defaultValue: "Clear History?"),
                isPresented: $showDeleteConfirmation
            ) {
                Button(String(localized: "action.cancel", defaultValue: "Cancel"), role: .cancel) {}
                Button(String(localized: "action.clearAll", defaultValue: "Clear All"), role: .destructive) {
                    clearAllHistory()
                }
            } message: {
                Text(String(localized: "history.clearConfirm.message", defaultValue: "This will permanently delete all your saved QR codes."))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                String(localized: "history.empty.title", defaultValue: "No History"),
                systemImage: "clock.arrow.circlepath"
            )
        } description: {
            Text(String(localized: "history.empty.description", defaultValue: "QR codes you create will appear here"))
        }
    }

    // MARK: - History List

    private var historyList: some View {
        List {
            ForEach(filteredItems) { item in
                HistoryItemRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedItem = item
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            deleteItem(item)
                        } label: {
                            Label(
                                String(localized: "action.delete", defaultValue: "Delete"),
                                systemImage: "trash"
                            )
                        }

                        if purchaseManager.isPro {
                            Button {
                                duplicateItem(item)
                            } label: {
                                Label(
                                    String(localized: "action.duplicate", defaultValue: "Duplicate"),
                                    systemImage: "doc.on.doc"
                                )
                            }
                            .tint(.blue)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .sheet(item: $selectedItem) { item in
            HistoryDetailView(item: item)
        }
    }

    // MARK: - Actions

    private func deleteItem(_ item: HistoryItem) {
        modelContext.delete(item)
    }

    private func duplicateItem(_ item: HistoryItem) {
        let duplicate = item.duplicate()
        modelContext.insert(duplicate)
    }

    private func clearAllHistory() {
        for item in historyItems {
            modelContext.delete(item)
        }
    }
}

// MARK: - History Item Row

struct HistoryItemRow: View {
    let item: HistoryItem

    private let renderer = QRCodeRenderer()
    @State private var previewImage: Image?

    var body: some View {
        HStack(spacing: 12) {
            // Mini preview
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.1))
                    .frame(width: 56, height: 56)

                if let image = previewImage {
                    image
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                // Title, or human-readable summary for complex types, else truncated content
                Text(displayTitle)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)

                // Data type and date
                HStack(spacing: 8) {
                    Label(item.parsedDataType.displayName, systemImage: item.parsedDataType.iconName)

                    Text("•")

                    Text(item.lastUsedAt, style: .relative)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .task {
            await generatePreview()
        }
    }

    private var displayTitle: String {
        if let title = item.title, !title.isEmpty { return title }
        if let summary = DataTypeDetector.summarize(item.content, for: item.parsedDataType),
           !summary.isEmpty {
            return summary
        }
        return String(item.content.prefix(50))
    }

    @MainActor
    private func generatePreview() async {
        let input = QRInput(content: item.content)
        previewImage = renderer.preview(
            input: input,
            configuration: item.getConfiguration(),
            previewSize: 100
        )
    }
}

// MARK: - History Detail View

struct HistoryDetailView: View {
    let item: HistoryItem

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var previewImage: Image?
    @State private var showExport = false
    @State private var copiedFeedback = false

    // Owned by this view so the sheet's ExportView always observes a populated,
    // stable instance. Populated from `item` on appear.
    @StateObject private var exportViewModel = GeneratorViewModel()

    private let renderer = QRCodeRenderer()
    private let exportService = ExportService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // QR Preview
                    if let image = previewImage {
                        image
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 280, maxHeight: 280)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.background)
                                    .shadow(radius: 10)
                            )
                    }

                    // Content info
                    VStack(spacing: 12) {
                        if let summary = DataTypeDetector.summarize(item.content, for: item.parsedDataType),
                           !summary.isEmpty,
                           summary != item.content {
                            InfoRow(
                                label: String(localized: "history.detail.summary", defaultValue: "Summary"),
                                value: summary
                            )
                        }

                        InfoRow(
                            label: String(localized: "history.detail.content", defaultValue: "Content"),
                            value: item.content
                        )

                        InfoRow(
                            label: String(localized: "history.detail.type", defaultValue: "Type"),
                            value: item.parsedDataType.displayName
                        )

                        InfoRow(
                            label: String(localized: "history.detail.created", defaultValue: "Created"),
                            value: item.createdAt.formatted(date: .abbreviated, time: .shortened)
                        )

                        InfoRow(
                            label: String(localized: "history.detail.usageCount", defaultValue: "Used"),
                            value: String(localized: "history.detail.times.count", defaultValue: "\(item.usageCount) times")
                        )
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.secondary.opacity(0.1))
                    )

                    // Actions
                    VStack(spacing: 12) {
                        Button {
                            Task {
                                await copyToClipboard()
                            }
                        } label: {
                            Label(
                                copiedFeedback
                                    ? String(localized: "action.copied", defaultValue: "Copied!")
                                    : String(localized: "action.copy", defaultValue: "Copy to Clipboard"),
                                systemImage: copiedFeedback ? "checkmark" : "doc.on.doc"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .tint(copiedFeedback ? .green : .accentColor)

                        Button {
                            showExport = true
                        } label: {
                            Label(
                                String(localized: "action.export", defaultValue: "Export"),
                                systemImage: "square.and.arrow.up"
                            )
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
            }
            .navigationTitle(item.title ?? String(localized: "history.detail.title", defaultValue: "QR Code"))
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "action.done", defaultValue: "Done")) {
                        // Update usage before dismissing
                        item.markUsed()
                        dismiss()
                    }
                }
            }
            .task {
                await generatePreview()
                // Pre-populate the export VM so the sheet's buttons aren't
                // disabled waiting for input.
                exportViewModel.inputText = item.content
                exportViewModel.configuration = item.getConfiguration()
            }
            .sheet(isPresented: $showExport) {
                ExportView(viewModel: exportViewModel)
            }
        }
    }

    @MainActor
    private func generatePreview() async {
        let input = QRInput(content: item.content)
        previewImage = renderer.preview(
            input: input,
            configuration: item.getConfiguration(),
            previewSize: 300
        )
    }

    private func copyToClipboard() async {
        let input = QRInput(content: item.content)
        let configuration = await MainActor.run { item.getConfiguration() }

        do {
            try await exportService.copyToClipboard(
                input: input,
                configuration: configuration,
                size: 512
            )

            await MainActor.run {
                withAnimation {
                    copiedFeedback = true
                }
            }

            try? await Task.sleep(nanoseconds: 2_000_000_000)

            await MainActor.run {
                withAnimation {
                    copiedFeedback = false
                }
            }
        } catch {
            // Handle error silently
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .textSelection(.enabled)

            Spacer()
        }
    }
}

// MARK: - Preview

#Preview {
    HistoryView()
        .environmentObject(PurchaseManager.shared)
        .modelContainer(for: HistoryItem.self, inMemory: true)
}
