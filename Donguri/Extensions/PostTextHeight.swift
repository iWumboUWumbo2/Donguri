//
//  PostTextHeight.swift
//  Donguri
//
//  Estimates how tall a post's text will render inside PostTextWebView.
//
//  Every post's text lives in its own WKWebView, which has no intrinsic content
//  size — the real height only arrives asynchronously, over the JS bridge, some
//  time after the row is already on screen. Rows used to start at 1pt and jump
//  to their real height once that message landed. SwiftUI does not clip content
//  that overflows its frame, and neither does a List cell, so when a burst of
//  those resizes landed at once the List kept drawing rows at stale offsets and
//  posts visibly overlapped each other.
//
//  Starting each row at a close estimate keeps the later correction down to a
//  few points, which the List absorbs without leaving stale offsets behind.
//  The estimate deliberately errs tall (it measures against a slightly narrower
//  width than the row really has): too tall only costs a moment's extra
//  whitespace, whereas too short is what put text on top of the next post.
//
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import UIKit

enum PostTextHeight {
    /// Mirrors `line-height: 1.5` in PostTextWebView's stylesheet. CSS resolves
    /// a unitless line-height against the font size, not the font's own metrics.
    private static let cssLineHeightMultiple: CGFloat = 1.5

    /// Rows are measured this much narrower than they really are, so the
    /// estimate lands slightly tall rather than slightly short.
    private static let widthSafetyMargin: CGFloat = 12

    private struct Key: Hashable {
        let text: String
        let width: CGFloat
        let contentSize: UIContentSizeCategory
    }

    private static var cache: [Key: CGFloat] = [:]

    /// Height `#post` is expected to report for `text` laid out at `width`.
    static func estimate(for text: String, width: CGFloat) -> CGFloat {
        let font = UIFont.preferredFont(forTextStyle: .body)
        let lineBox = font.pointSize * cssLineHeightMultiple
        let usableWidth = width - widthSafetyMargin

        guard usableWidth > 0 else { return lineBox }

        // Quantise the width so a few stray points of layout jitter don't blow
        // the cache on every frame of a scroll.
        let key = Key(text: text,
                      width: usableWidth.rounded(),
                      contentSize: UIApplication.shared.preferredContentSizeCategory)
        if let cached = cache[key] { return cached }

        let measured = displayText(for: text)

        // Pin the line height to the CSS line box so the measured result is
        // already in the webview's units — deriving a line count from the
        // font's own metrics and multiplying was off by a whole line whenever
        // the two differed by even a fraction.
        //
        // The stylesheet sets `overflow-wrap: anywhere`, which TextKit has no
        // single equivalent for: word wrapping lets an over-long token (a bare
        // URL, typically) hang off the edge on one line and so undercounts,
        // while character wrapping packs ordinary prose tighter than the
        // webview will. Measuring both and keeping the taller result covers
        // each case, and keeps the estimate on the safe side.
        func height(breaking mode: NSLineBreakMode) -> CGFloat {
            let paragraph = NSMutableParagraphStyle()
            paragraph.minimumLineHeight = lineBox
            paragraph.maximumLineHeight = lineBox
            paragraph.lineBreakMode = mode

            return (measured as NSString).boundingRect(
                with: CGSize(width: key.width, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: font, .paragraphStyle: paragraph],
                context: nil
            ).height
        }

        // A trailing newline becomes a trailing `<br>`, which lays out one more
        // (empty) line box in the webview. TextKit drops that final empty line,
        // so add it back.
        let trailingBreak = measured.hasSuffix("\n") ? lineBox : 0

        let height = (max(lineBox,
                          height(breaking: .byWordWrapping),
                          height(breaking: .byCharWrapping)) + trailingBreak).rounded(.up)

        if cache.count > 2000 { cache.removeAll(keepingCapacity: true) }
        cache[key] = height
        return height
    }

    /// `PostService` hands us markdown-ish text — `>>N` anchors arrive as
    /// `[>>N](donguri://res/N)`. Only the label is rendered, so only the label
    /// should be measured.
    private static func displayText(for text: String) -> String {
        text.replacing(#/\[([^\]]*)\]\(([^)\s]+)\)/#) { match in
            String(match.1)
        }
    }
}
