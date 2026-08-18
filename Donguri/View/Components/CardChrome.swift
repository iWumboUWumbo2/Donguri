//
//  CardChrome.swift
//  Donguri
//
//  Created by John Connery on 8/17/26.
//

import SwiftUI

/// Small pill/badge used for counts and tags (reply counts, post index, ID/trip).
struct Chip: View {
    var text: String
    var systemImage: String?
    var tint: Color = .accentColor
    var filled: Bool = true

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            Text(text)
                .monospacedDigit()
        }
        .font(.caption2.weight(.semibold))
        .foregroundStyle(filled ? tint : .secondary)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(
            Capsule().fill(filled ? tint.opacity(0.14) : Color.secondary.opacity(0.1))
        )
    }
}

/// Floating-card recipe shared across post cards, popups, and pills: a fill,
/// a hairline stroke, and a gentle shadow — matches Hoshi-Reader's
/// `BookCover` treatment.
private struct CardBackground<Fill: ShapeStyle>: ViewModifier {
    var cornerRadius: CGFloat
    var fill: Fill

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background(fill, in: shape)
            .overlay {
                shape.stroke(.primary.opacity(0.08), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.12), radius: 3, x: 0, y: 2)
    }
}

extension View {
    /// Translucent material card — for content that floats over other
    /// content, like popups and pills, where blending with what's behind
    /// is the point.
    func cardBackground(cornerRadius: CGFloat) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, fill: .ultraThinMaterial))
    }

    /// Opaque elevated card — for content sitting directly on a grouped
    /// background (e.g. `.systemGroupedBackground`), where a translucent
    /// material would blend into the page instead of standing apart from it.
    func cardBackground(cornerRadius: CGFloat, fill: Color) -> some View {
        modifier(CardBackground(cornerRadius: cornerRadius, fill: fill))
    }
}
