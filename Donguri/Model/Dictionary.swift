//
//  Dictionary.swift
//  Donguri
//
//  Ported from Hoshi Reader.
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation

struct DictionaryInfo: Identifiable, Codable {
    let id: UUID
    let index: DictionaryIndex
    let path: URL
    var isEnabled: Bool
    var order: Int

    init(id: UUID = UUID(), index: DictionaryIndex, path: URL, isEnabled: Bool = true, order: Int = 0) {
        self.id = id
        self.index = index
        self.path = path
        self.isEnabled = isEnabled
        self.order = order
    }
}

struct DictionaryConfig: Codable {
    var termDictionaries: [DictionaryEntry]
    var frequencyDictionaries: [DictionaryEntry]
    var pitchDictionaries: [DictionaryEntry]

    struct DictionaryEntry: Codable {
        let fileName: String
        var isEnabled: Bool
        var order: Int
    }
}

/// Decodes two shapes with the same fields:
///  - a Yomitan dictionary's own `index.json` (uses `format`, and carries the
///    self-update URLs), and
///  - the summary hoshidicts writes back out after importing (uses `version`,
///    and omits the update fields entirely when absent).
///
/// Everything but `title` is therefore lenient — a strict decode silently loses
/// dictionaries, because `DictionaryManager.getDictionariesFromStorage` deletes
/// any dictionary directory whose index it can't read.
nonisolated struct DictionaryIndex: Codable {
    let title: String
    let format: Int
    let revision: String
    let isUpdatable: Bool
    let indexUrl: String
    let downloadUrl: String

    private enum CodingKeys: String, CodingKey {
        case title, format, version, revision, isUpdatable, indexUrl, downloadUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decode(String.self, forKey: .title)
        revision = (try? container.decode(String.self, forKey: .revision)) ?? ""
        format = (try? container.decode(Int.self, forKey: .format))
            ?? (try? container.decode(Int.self, forKey: .version))
            ?? 3
        isUpdatable = (try? container.decode(Bool.self, forKey: .isUpdatable)) ?? false
        indexUrl = (try? container.decode(String.self, forKey: .indexUrl)) ?? ""
        downloadUrl = (try? container.decode(String.self, forKey: .downloadUrl)) ?? ""
    }

    // `version` has no stored property, so the encode side can't be synthesised.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(format, forKey: .format)
        try container.encode(revision, forKey: .revision)
        try container.encode(isUpdatable, forKey: .isUpdatable)
        try container.encode(indexUrl, forKey: .indexUrl)
        try container.encode(downloadUrl, forKey: .downloadUrl)
    }
}

struct AudioSource: Codable, Identifiable {
    var id: String { url }
    var name: String
    let url: String
    var isEnabled: Bool
    let isDefault: Bool

    init(name: String = "", url: String, isEnabled: Bool = true, isDefault: Bool = false) {
        self.name = name
        self.url = url
        self.isEnabled = isEnabled
        self.isDefault = isDefault
    }
}
