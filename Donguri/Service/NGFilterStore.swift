//
//  NGFilterStore.swift
//  Donguri
//
//  Created by John Connery on 9/3/26.
//

import Foundation
import SwiftUI

/// Stores the user's NG (あぼーん) rules and decides which posts they hide.
///
/// Filtered posts are never removed from the thread's post array — `>>N` links
/// and `Post.replies` are both plain indices into it, so dropping elements would
/// silently misnumber every later reply. `ThreadView` renders a placeholder row
/// in place of a hidden post instead.
@Observable
final class NGFilterStore {
    static let shared = NGFilterStore()

    private static let defaultsKey = "donguri.ngRules"

    private(set) var rules: [NGRule]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([NGRule].self, from: data) {
            rules = decoded
        } else {
            rules = []
        }
    }

    func add(kind: NGRule.Kind, pattern: String) {
        let trimmed = pattern.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !rules.contains(where: { $0.kind == kind && $0.pattern == trimmed }) else { return }
        rules.append(NGRule(kind: kind, pattern: trimmed))
        persist()
    }

    func remove(atOffsets offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        persist()
    }

    func remove(kind: NGRule.Kind, pattern: String) {
        rules.removeAll { $0.kind == kind && $0.pattern == pattern }
        persist()
    }

    func contains(kind: NGRule.Kind, pattern: String) -> Bool {
        rules.contains { $0.kind == kind && $0.pattern == pattern }
    }

    /// Case-insensitive substring match, which is what 5ch clients do by default.
    func hides(_ post: Post) -> Bool {
        guard !rules.isEmpty else { return false }

        for rule in rules {
            switch rule.kind {
            case .word:
                if post.text.localizedCaseInsensitiveContains(rule.pattern) { return true }
            case .id:
                if let id = post.id, id.localizedCaseInsensitiveContains(rule.pattern) { return true }
            case .name:
                if post.name.localizedCaseInsensitiveContains(rule.pattern) { return true }
                if let trip = post.trip, trip.localizedCaseInsensitiveContains(rule.pattern) { return true }
            }
        }
        return false
    }

    /// Indices of every post in `posts` hidden by the current rules.
    func hiddenIndices(in posts: [Post]) -> Set<Int> {
        guard !rules.isEmpty else { return [] }
        var hidden = Set<Int>()
        for (index, post) in posts.enumerated() where hides(post) {
            hidden.insert(index)
        }
        return hidden
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(rules) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
