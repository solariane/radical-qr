import SwiftUI

/// The frame every content form shares — event, Wi-Fi, contact: a card, a header
/// naming the type with the ways out, then the form's own rows.
struct EditorCard<Content: View>: View {
    let type: DataType
    /// Replaces the type's name when the form means something narrower —
    /// a place is an address, not the coordinates `DataType.geo` names.
    var title: String? = nil
    /// `nil` when there is no text to go back to (content loaded from history).
    let onKeepAsText: (() -> Void)?
    let onClear: () -> Void
    @ViewBuilder let content: () -> Content

    @Environment(\.generatorMetrics) private var metrics

    var body: some View {
        VStack(alignment: .leading, spacing: metrics.rowGap) {
            header
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(padding: metrics.cardPadding, cornerRadius: 26)
    }

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: type.iconName)
                .foregroundStyle(Color.accentColor)
            Text(title ?? type.displayName)
                .font(.headline)
            Spacer(minLength: 8)
            if let onKeepAsText {
                Button(String(localized: "editor.keepAsText", defaultValue: "Keep as text",
                              comment: "Button: undo the automatic conversion of pasted text into a calendar event, Wi-Fi network, contact card or Maps link, and encode the original text instead."),
                       action: onKeepAsText)
                    .font(.subheadline)
                    .buttonStyle(.borderless)
            }
            Button(action: onClear) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "editor.clear", defaultValue: "Clear",
                                       comment: "Accessibility label: erase the content being encoded and start over."))
        }
    }
}

extension View {
    /// The grey rounded field every form row uses.
    func editorFieldBackground() -> some View {
        padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.secondary.opacity(0.11))
            )
    }
}

/// A folded optional field: a capsule that unfolds into the field when tapped.
/// It shows the field's name after a plus — "＋ Entreprise" — because the
/// sentence ("Ajouter une entreprise") puts one button per line in French;
/// VoiceOver still reads the sentence.
struct AddFieldButton: View {
    /// The field's name, as its placeholder says it.
    let title: String
    /// What the button does, for VoiceOver.
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: { withAnimation(.easeInOut(duration: 0.2), action) }) {
            Label(title, systemImage: "plus")
                .font(.subheadline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Capsule().fill(Color.secondary.opacity(0.12)))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Folded fields side by side, wrapping onto a second line when the labels do
/// not fit — "Ajouter une entreprise" is a lot longer than "Add company".
struct AddFieldRow: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let width = rows.map { row in row.reduce(0) { $0 + $1.width } + spacing * CGFloat(max(row.count - 1, 0)) }.max() ?? 0
        let height = rows.map { $0.map(\.height).max() ?? 0 }.reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        var index = 0
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            let rowHeight = row.map(\.height).max() ?? 0
            for size in row {
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
                index += 1
            }
            y += rowHeight + spacing
        }
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [[CGSize]] {
        var rows: [[CGSize]] = [[]]
        var rowWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if let last = rows.indices.last, !rows[last].isEmpty, rowWidth + spacing + size.width > width {
                rows.append([size])
                rowWidth = size.width
            } else {
                rows[rows.count - 1].append(size)
                rowWidth += (rows[rows.count - 1].count > 1 ? spacing : 0) + size.width
            }
        }
        return rows
    }
}
