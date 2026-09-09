//
//  NGRule.swift
//  Donguri
//
//  Created by John Connery on 9/3/26.
//

import Foundation

/// One NG (あぼーん) rule. 5ch clients traditionally filter on the post body
/// (NGワード), the poster's ID (NGID) or their name/tripcode (NG名前).
struct NGRule: Codable, Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case word
        case id
        case name

        var id: String { rawValue }

        /// `String(localized:)` rather than a bare literal — this is a plain
        /// `String` property, so nothing would look it up otherwise.
        var label: String {
            switch self {
            case .word: String(localized: "NGワード")
            case .id: String(localized: "NG ID")
            case .name: String(localized: "NG名前")
            }
        }
    }

    var id: UUID = UUID()
    var kind: Kind
    var pattern: String
}
