//
//  TouchTarget.swift
//  Radical QR
//
//  A plain button answers only where its label draws: an 18pt cross is an
//  18pt target. Fine for a pointer, too small for a finger — iOS asks for
//  44pt, Touch on Mac for 36pt. This widens the tap area without moving
//  anything: the padding added for hit testing is taken back for layout, so
//  the vertical budget of the generator is unchanged.
//

import SwiftUI

extension View {
    /// Extends the tappable area by `inset` on every side, layout untouched.
    /// Use on the label of a `.plain` icon button: inset = (44 − glyph) / 2.
    /// Beside another control, keep `leading` / `trailing` to half the stack
    /// spacing: the later view is on top, and would take the neighbour's taps.
    func touchTarget(_ inset: CGFloat = 12, leading: CGFloat? = nil, trailing: CGFloat? = nil) -> some View {
        let insets = EdgeInsets(top: inset, leading: leading ?? inset, bottom: inset, trailing: trailing ?? inset)
        return padding(insets)
            .contentShape(Rectangle())
            .padding(EdgeInsets(top: -insets.top, leading: -insets.leading, bottom: -insets.bottom, trailing: -insets.trailing))
    }
}

#Preview {
    HStack(spacing: 0) {
        Text(verbatim: "Field")
        Spacer()
        Button {} label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.secondary)
                .touchTarget()
        }
        .buttonStyle(.plain)
    }
    .padding()
}
