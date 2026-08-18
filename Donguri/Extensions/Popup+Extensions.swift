//
//  Popup+Extensions.swift
//  Donguri
//
//  Small utilities ported from Hoshi Reader's Util/Extensions.swift, trimmed to
//  just what the popup dictionary / Anki port needs.
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import CryptoKit
import Foundation
import SwiftUI
import UIKit

extension Data {
    var sha1: String {
        Insecure.SHA1.hash(data: self).map { String(format: "%02x", $0) }.joined()
    }
}

extension UIApplication {
    static var topSafeArea: CGFloat {
        (shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?
            .safeAreaInsets.top ?? 0
    }

    static var bottomSafeArea: CGFloat {
        (shared.connectedScenes.first as? UIWindowScene)?
            .keyWindow?
            .safeAreaInsets.bottom ?? 0
    }
}

extension View {
    @ViewBuilder
    func conditionalGlassEffect() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(.regular.interactive())
        } else {
            self
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.quaternary, lineWidth: 0.5))
                .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }
}

struct LoadingOverlay: View {
    let message: String

    init(_ message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
            Group {
                if #available(iOS 26, *) {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(message)
                            .lineLimit(1)
                    }
                    .padding(24)
                    .glassEffect()
                } else {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text(message)
                            .lineLimit(1)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(24)
        }
    }
}
