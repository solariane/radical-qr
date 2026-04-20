import SwiftUI
import SwiftData

/// Horizontal strip of recent QR codes shown on the generator page.
/// Clicking a thumbnail loads its content + configuration into the generator
/// for quick variant creation.
struct RecentHistoryStrip: View {
    @Query(
        sort: \HistoryItem.lastUsedAt,
        order: .reverse
    )
    private var allItems: [HistoryItem]

    let onSelect: (HistoryItem) -> Void

    private let maxItems = 12
    private let thumbnailSize: CGFloat = 64

    private var recentItems: [HistoryItem] {
        Array(allItems.prefix(maxItems))
    }

    var body: some View {
        if recentItems.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text(String(localized: "history.recent", defaultValue: "Recent"))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.horizontal, 4)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentItems) { item in
                            RecentHistoryThumbnail(
                                item: item,
                                size: thumbnailSize
                            ) {
                                onSelect(item)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }
}

// MARK: - Thumbnail

private struct RecentHistoryThumbnail: View {
    let item: HistoryItem
    let size: CGFloat
    let action: () -> Void

    @State private var previewImage: Image?

    private let renderer = QRCodeRenderer()

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.white)

                    if let image = previewImage {
                        image
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .padding(6)
                    } else {
                        Image(systemName: item.parsedDataType.iconName)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )

                Text(contentPreview)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
                    .frame(width: size, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .help(tooltipText)
        .task {
            await generatePreview()
        }
    }

    /// Prefer the explicit title, else the parsed human-readable summary
    /// (e.g. "John Doe • john@ex.com" for a vCard), falling back to a
    /// truncated view of the raw content for plain text.
    private var contentPreview: String {
        if let title = item.title, !title.isEmpty { return title }
        if let summary = DataTypeDetector.summarize(item.content, for: item.parsedDataType),
           !summary.isEmpty {
            return summary
        }
        let trimmed = item.content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= 20 { return trimmed }
        return String(trimmed.prefix(18)) + "…"
    }

    private var tooltipText: String {
        let typeName = item.parsedDataType.displayName
        if let summary = DataTypeDetector.summarize(item.content, for: item.parsedDataType),
           !summary.isEmpty {
            return "\(typeName) — \(summary)"
        }
        return typeName
    }

    @MainActor
    private func generatePreview() async {
        let input = QRInput(content: item.content)
        previewImage = renderer.preview(
            input: input,
            configuration: item.getConfiguration(),
            previewSize: 120
        )
    }
}

#Preview {
    ZStack {
        GradientBackground()
        RecentHistoryStrip { _ in }
            .padding()
    }
    .modelContainer(for: HistoryItem.self, inMemory: true)
}
