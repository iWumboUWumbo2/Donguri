//
//  PostTextWebView.swift
//  Donguri
//
//  Renders one post's text in a WKWebView so Hoshi Reader's selection.js can do
//  tap-to-lookup on it — SwiftUI Text has no per-character hit testing, so this
//  is the one piece the port couldn't reuse directly. Modeled on Hoshi Reader's
//  ReaderWebView.swift coordinator/message-handler pattern, minus everything
//  pagination-, chapter-, highlight- and sasayaki-related.
//
//  Unlike Hoshi's single full-screen reader webview (where webview coordinates
//  are already screen coordinates), each post is its own small webview inside a
//  scrolling List, so selection rects are converted to window coordinates before
//  being handed to SwiftUI.
//
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI
import UIKit
import WebKit

struct SelectionData {
    let text: String
    let sentence: String
    let rect: CGRect
    var normalizedOffset: Int? = nil
}

struct PostTextWebView: UIViewRepresentable {
    let html: String
    let scanNonJapaneseText: Bool
    var maxSelectionLength: Int = 16
    var onTextSelected: (SelectionData) -> Int?
    var onTapOutside: () -> Void
    var onPostReply: (Int) -> Void
    var onThreadRoute: (ThreadRoute) -> Void
    var onHeightChange: (CGFloat) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "textSelected")
        config.userContentController.add(context.coordinator, name: "contentHeight")
        config.defaultWebpagePreferences.preferredContentMode = .mobile

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator

        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        tap.delegate = context.coordinator
        tap.cancelsTouchesInView = false
        tap.delaysTouchesEnded = false
        webView.addGestureRecognizer(tap)

        context.coordinator.webView = webView
        webView.loadHTMLString(context.coordinator.document(for: html), baseURL: Bundle.main.resourceURL)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        if context.coordinator.loadedHTML != html {
            context.coordinator.loadedHTML = html
            webView.loadHTMLString(context.coordinator.document(for: html), baseURL: Bundle.main.resourceURL)
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "textSelected")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "contentHeight")
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIGestureRecognizerDelegate {
        var parent: PostTextWebView
        weak var webView: WKWebView?
        var loadedHTML: String?

        init(parent: PostTextWebView) {
            self.parent = parent
            self.loadedHTML = parent.html
        }

        private var selectionJs: String {
            guard let url = Bundle.main.url(forResource: "selection", withExtension: "js"),
                  let js = try? String(contentsOf: url, encoding: .utf8) else {
                return ""
            }
            return js
        }

        func document(for html: String) -> String {
            """
            <!DOCTYPE html>
            <html>
            <head>
                <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                <style>
                    :root { color-scheme: light dark; }
                    html, body {
                        margin: 0; padding: 0;
                        background: transparent;
                        font: -apple-system-body;
                        font-family: -apple-system, "Hiragino Kaku Gothic ProN", sans-serif;
                        line-height: 1.5;
                        -webkit-text-size-adjust: none;
                        overflow-wrap: anywhere;
                    }
                    a { color: rgba(66, 108, 245, 1); }
                    ::highlight(hoshi-selection) {
                        background-color: rgba(160, 160, 160, 0.4);
                        color: inherit;
                    }
                </style>
            </head>
            <body>
                <div id="post">\(html)</div>
                <script>
                    window.scanNonJapaneseText = \(parent.scanNonJapaneseText);
                    \(selectionJs)
                    // WKWebView has no intrinsic content size — report height so the
                    // SwiftUI row can size itself, and again whenever layout changes.
                    function reportHeight() {
                        webkit.messageHandlers.contentHeight.postMessage(
                            document.getElementById('post').getBoundingClientRect().height
                        );
                    }
                    new ResizeObserver(reportHeight).observe(document.getElementById('post'));
                    reportHeight();
                </script>
            </body>
            </html>
            """
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "contentHeight", let height = message.body as? CGFloat {
                parent.onHeightChange(height)
                return
            }

            guard message.name == "textSelected",
                  let body = message.body as? [String: Any],
                  let text = body["text"] as? String,
                  let sentence = body["sentence"] as? String,
                  let rectData = body["rect"] as? [String: Any],
                  let x = rectData["x"] as? CGFloat,
                  let y = rectData["y"] as? CGFloat,
                  let w = rectData["width"] as? CGFloat,
                  let h = rectData["height"] as? CGFloat,
                  let webView = message.webView else {
                return
            }

            // Convert from this post's webview space into window space, so the
            // popup positions correctly regardless of List scroll offset.
            let localRect = CGRect(x: x, y: y, width: w, height: h)
            let windowRect = webView.convert(localRect, to: nil)

            let selection = SelectionData(text: text, sentence: sentence, rect: windowRect)
            if let highlightCount = parent.onTextSelected(selection) {
                webView.evaluateJavaScript("window.hoshiSelection.highlightSelection(\(highlightCount))")
            }
        }

        @MainActor
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void) {
            guard navigationAction.navigationType == .linkActivated,
                  let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // Same-thread reply anchor (>>N)
            if url.scheme == "donguri", url.host == "res",
               let number = Int(url.lastPathComponent), number >= 1 {
                parent.onPostReply(number - 1)
                decisionHandler(.cancel)
                return
            }

            // Link to another 5ch thread
            if let route = Self.parseThreadLink(url: url) {
                parent.onThreadRoute(route)
                decisionHandler(.cancel)
                return
            }

            if url.scheme == "http" || url.scheme == "https" {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            guard let webView else { return }
            let point = gesture.location(in: webView)
            let script = "window.hoshiSelection.selectText(\(point.x), \(point.y), \(parent.maxSelectionLength))"
            webView.evaluateJavaScript(script) { result, _ in
                if result is NSNull || result == nil {
                    self.parent.onTapOutside()
                }
            }
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            !(other is UILongPressGestureRecognizer)
        }

        static func parseThreadLink(url: URL) -> ThreadRoute? {
            guard let host = url.host, host.contains(".5ch.") else {
                return nil
            }
            let components = url.pathComponents
            guard let cgiIndex = components.firstIndex(of: "read.cgi"),
                  components.count > cgiIndex + 2,
                  let threadId = Int(components[cgiIndex + 2]) else {
                return nil
            }
            let directoryName = components[cgiIndex + 1]
            return ThreadRoute(boardURL: "https://\(host)/\(directoryName)/", threadId: threadId)
        }
    }
}
