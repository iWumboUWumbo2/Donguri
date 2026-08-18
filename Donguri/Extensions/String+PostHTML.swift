//
//  String+PostHTML.swift
//  Donguri
//
//  Created by John Connery on 8/18/26.
//

import Foundation

extension String {
    /// Renders post text as HTML for `PostTextWebView`.
    ///
    /// `PostService` normalises the raw dat/HTML into markdown-ish text (`>>N`
    /// anchors become `[>>N](donguri://res/N)` links) for SwiftUI's `Text`. The
    /// webview needs real HTML, so escape everything first — the text is
    /// untrusted user content from 5ch and must never be injected as markup —
    /// then re-introduce only the links and line breaks we put there ourselves.
    var asPostHTML: String {
        var s = self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")

        // Markdown links produced by PostService: [label](url). These are pulled
        // out first and replaced with a placeholder so the bare-URL pass below
        // can't mangle the URLs inside them; they're restored at the end.
        var extracted: [String] = []
        s = s.replacing(#/\[([^\]]*)\]\(([^)\s]+)\)/#) { match in
            let label = String(match.1)
            let href = String(match.2)
            // Only schemes this app actually creates or follows.
            guard href.hasPrefix("donguri://") || href.hasPrefix("http://") || href.hasPrefix("https://") else {
                return label
            }
            extracted.append("<a href=\"\(href)\">\(label)</a>")
            return "\u{FFFC}\(extracted.count - 1)\u{FFFC}"
        }

        // Bare URLs — SwiftUI's Text auto-linkified these, so match that.
        s = s.replacing(#/https?:\/\/[^\s<>"']+/#) { match in
            let url = String(match.0)
            return "<a href=\"\(url)\">\(url)</a>"
        }

        s = s.replacing(#/\u{FFFC}(\d+)\u{FFFC}/#) { match in
            Int(match.1).map { extracted[$0] } ?? ""
        }

        return s.replacingOccurrences(of: "\n", with: "<br>")
    }
}
