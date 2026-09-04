//
//  ReportService.swift
//  Donguri
//
//  Created by John Connery on 9/3/26.
//

import Foundation
import UIKit

/// Reporting objectionable posts.
///
/// Donguri displays user-generated content it doesn't host or moderate, so the
/// App Store review guidelines (1.2) require a way for users to report it. This
/// composes a mail to the app's support address with enough context to identify
/// the post upstream.
enum ReportService {
    /// Where reports are sent. Also publish this as the support address in
    /// App Store Connect — the guidelines expect the two to match.
    static let supportEmail = "john.connery3223@gmail.com"

    static func canReport() -> Bool {
        URL(string: "mailto:\(supportEmail)").map { UIApplication.shared.canOpenURL($0) } ?? false
    }

    /// Opens the user's mail client with a pre-filled report. Nothing is sent
    /// automatically — the user reviews and sends it themselves.
    static func report(post: Post, index: Int, boardURL: String, threadId: Int, threadTitle: String?) {
        let subject = "[Donguri] 不適切な書き込みの通報 / Content report"

        let body = """
        不適切な書き込みを通報します。
        Reporting a post as objectionable.

        ── 対象 / Reported post ──────────────
        スレッド / Thread: \(threadTitle ?? "-")
        URL: \(threadURL(boardURL: boardURL, threadId: threadId))
        レス番号 / Post: >>\(index + 1)
        名前 / Name: \(post.name)
        ID: \(post.id ?? "-")
        日時 / Date: \(post.date)

        ── 本文 / Content ───────────────────
        \(post.text.prefix(1000))

        ── 通報理由 / Reason ────────────────
        (ここに理由をご記入ください / please describe the problem here)
        """

        var components = URLComponents()
        components.scheme = "mailto"
        components.path = supportEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body),
        ]

        // mailto requires percent-encoded spaces; URLComponents emits "+".
        let encoded = components.string?.replacingOccurrences(of: "+", with: "%20")
        guard let string = encoded, let url = URL(string: string) else { return }
        UIApplication.shared.open(url)
    }

    private static func threadURL(boardURL: String, threadId: Int) -> String {
        guard let url = URL(string: boardURL), let host = url.host else {
            return "\(boardURL) / \(threadId)"
        }
        let directory = url.pathComponents.first { $0 != "/" } ?? ""
        return "https://\(host)/test/read.cgi/\(directory)/\(threadId)/"
    }
}
