//
//  ReadStateStore.swift
//  Donguri
//
//  Created by John Connery on 8/17/26.
//

import Foundation

/// Tracks how far the user has read into each thread, so the board list can
/// show an unread count and reopening a thread can resume near where the
/// user left off. Backed by `UserDefaults`, cached in memory.
final class ReadStateStore {
    static let shared = ReadStateStore()

    private static let defaultsKey = "donguri.readState"

    private var cache: [String: ReadState]

    private init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let decoded = try? JSONDecoder().decode([String: ReadState].self, from: data) {
            cache = decoded
        } else {
            cache = [:]
        }
    }

    static func key(boardURL: String, threadId: Int) -> String {
        "\(boardURL)|\(threadId)"
    }

    func state(for key: String) -> ReadState? {
        cache[key]
    }

    func update(key: String, postCount: Int, readIndex: Int) {
        let existing = cache[key]
        cache[key] = ReadState(
            lastReadCount: max(existing?.lastReadCount ?? 0, postCount),
            lastReadIndex: max(existing?.lastReadIndex ?? 0, readIndex)
        )
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(cache) else { return }
        UserDefaults.standard.set(data, forKey: Self.defaultsKey)
    }
}
