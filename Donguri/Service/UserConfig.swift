//
//  UserConfig.swift
//  Donguri
//
//  Trimmed from Hoshi Reader's UserConfig.swift: only the dictionary/popup/audio/
//  Anki-adjacent settings the ported popup dictionary views actually read. Kept
//  the same class name and UserDefaults-backed pattern so the ported views'
//  `@Environment(UserConfig.self)` / `Bindable(userConfig)` code needs no changes.
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation
import SwiftUI

enum DictionaryUpdateInterval: String, CaseIterable, Codable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var timeInterval: TimeInterval {
        switch self {
        case .daily:
            24 * 60 * 60
        case .weekly:
            7 * 24 * 60 * 60
        case .monthly:
            30 * 24 * 60 * 60
        }
    }
}

enum AudioPlaybackMode: String, CaseIterable, Codable {
    case interrupt = "interrupt"
    case duck = "duck"
    case mix = "mix"
}

enum CollapseMode: String, CaseIterable, Codable {
    case expandAll = "Expand All"
    case collapseAll = "Collapse All"
    case custom = "Custom"
}

@Observable
class UserConfig {
    var autoUpdateDictionaries: Bool {
        didSet { UserDefaults.standard.set(autoUpdateDictionaries, forKey: "autoUpdateDictionaries") }
    }

    var dictionaryUpdateInterval: DictionaryUpdateInterval {
        didSet { UserDefaults.standard.set(dictionaryUpdateInterval.rawValue, forKey: "dictionaryUpdateInterval") }
    }

    var dictionaryTabDefault: Bool {
        didSet { UserDefaults.standard.set(dictionaryTabDefault, forKey: "dictionaryTabDefault") }
    }

    var scanNonJapaneseText: Bool {
        didSet { UserDefaults.standard.set(scanNonJapaneseText, forKey: "scanNonJapaneseText") }
    }

    var maxResults: Int {
        didSet { UserDefaults.standard.set(maxResults, forKey: "maxResults") }
    }

    var scanLength: Int {
        didSet { UserDefaults.standard.set(scanLength, forKey: "scanLength") }
    }

    var collapseMode: CollapseMode {
        didSet { UserDefaults.standard.set(collapseMode.rawValue, forKey: "collapseMode") }
    }

    var expandFirstDictionary: Bool {
        didSet { UserDefaults.standard.set(expandFirstDictionary, forKey: "expandFirstDictionary") }
    }

    var twoColumnLayout: Bool {
        didSet { UserDefaults.standard.set(twoColumnLayout, forKey: "twoColumnLayout") }
    }

    var compactGlossaries: Bool {
        didSet { UserDefaults.standard.set(compactGlossaries, forKey: "compactGlossaries") }
    }

    var showExpressionTags: Bool {
        didSet { UserDefaults.standard.set(showExpressionTags, forKey: "showExpressionTags") }
    }

    var harmonicFrequency: Bool {
        didSet { UserDefaults.standard.set(harmonicFrequency, forKey: "harmonicFrequency") }
    }

    var deduplicatePitchAccents: Bool {
        didSet { UserDefaults.standard.set(deduplicatePitchAccents, forKey: "deduplicatePitchAccents") }
    }

    var compactPitchAccents: Bool {
        didSet { UserDefaults.standard.set(compactPitchAccents, forKey: "compactPitchAccents") }
    }

    var popupWidth: Int {
        didSet { UserDefaults.standard.set(popupWidth, forKey: "popupWidth") }
    }

    var popupHeight: Int {
        didSet { UserDefaults.standard.set(popupHeight, forKey: "popupHeight") }
    }

    var popupScale: Double {
        didSet { UserDefaults.standard.set(popupScale, forKey: "popupScale") }
    }

    var popupActionBar: Bool {
        didSet { UserDefaults.standard.set(popupActionBar, forKey: "popupActionBar") }
    }

    var popupDisableTransparency: Bool {
        didSet { UserDefaults.standard.set(popupDisableTransparency, forKey: "popupDisableTransparency") }
    }

    var popupFullWidth: Bool {
        didSet { UserDefaults.standard.set(popupFullWidth, forKey: "popupFullWidth") }
    }

    var popupSwipeToDismiss: Bool {
        didSet { UserDefaults.standard.set(popupSwipeToDismiss, forKey: "popupSwipeToDismiss") }
    }

    var popupSwipeThreshold: Int {
        didSet { UserDefaults.standard.set(popupSwipeThreshold, forKey: "popupSwipeThreshold") }
    }

    var audioSources: [AudioSource] {
        didSet {
            if let data = try? JSONEncoder().encode(audioSources) {
                UserDefaults.standard.set(data, forKey: "audioSources")
            }
        }
    }

    var audioEnableAutoplay: Bool {
        didSet { UserDefaults.standard.set(audioEnableAutoplay, forKey: "audioEnableAutoplay") }
    }

    var audioPlaybackMode: AudioPlaybackMode {
        didSet { UserDefaults.standard.set(audioPlaybackMode.rawValue, forKey: "audioPlaybackMode") }
    }

    var enabledAudioSources: [String] {
        audioSources.filter { $0.isEnabled }.map { $0.url }
    }

    static let defaultAudioSource = AudioSource(
        name: "Default",
        url: "https://hoshi-reader.manhhaoo-do.workers.dev/?term={term}&reading={reading}",
        isEnabled: true,
        isDefault: true
    )

    var customCSS: String {
        didSet { UserDefaults.standard.set(customCSS, forKey: "customCSS") }
    }

    init() {
        let defaults = UserDefaults.standard

        self.autoUpdateDictionaries = defaults.object(forKey: "autoUpdateDictionaries") as? Bool ?? true
        self.dictionaryUpdateInterval = defaults.string(forKey: "dictionaryUpdateInterval")
            .flatMap(DictionaryUpdateInterval.init) ?? .weekly
        self.dictionaryTabDefault = defaults.object(forKey: "dictionaryTabDefault") as? Bool ?? false
        self.scanNonJapaneseText = defaults.object(forKey: "scanNonJapaneseText") as? Bool ?? true
        self.maxResults = defaults.object(forKey: "maxResults") as? Int ?? 16
        self.scanLength = defaults.object(forKey: "scanLength") as? Int ?? 16
        self.collapseMode = defaults.string(forKey: "collapseMode")
            .flatMap(CollapseMode.init) ?? .expandAll
        self.expandFirstDictionary = defaults.object(forKey: "expandFirstDictionary") as? Bool ?? false
        self.twoColumnLayout = defaults.object(forKey: "twoColumnLayout") as? Bool ?? false
        self.compactGlossaries = defaults.object(forKey: "compactGlossaries") as? Bool ?? true
        self.showExpressionTags = defaults.object(forKey: "showExpressionTags") as? Bool ?? false
        self.harmonicFrequency = defaults.object(forKey: "harmonicFrequency") as? Bool ?? false
        self.deduplicatePitchAccents = defaults.object(forKey: "deduplicatePitchAccents") as? Bool ?? false
        self.compactPitchAccents = defaults.object(forKey: "compactPitchAccents") as? Bool ?? true

        self.popupWidth = defaults.object(forKey: "popupWidth") as? Int ?? 320
        self.popupHeight = defaults.object(forKey: "popupHeight") as? Int ?? 250
        self.popupScale = defaults.object(forKey: "popupScale") as? Double ?? 1.0
        self.popupActionBar = defaults.object(forKey: "popupActionBar") as? Bool ?? false
        self.popupDisableTransparency = defaults.object(forKey: "popupDisableTransparency") as? Bool ?? false
        self.popupFullWidth = defaults.object(forKey: "popupFullWidth") as? Bool ?? false
        self.popupSwipeToDismiss = defaults.object(forKey: "popupSwipeToDismiss") as? Bool ?? false
        self.popupSwipeThreshold = defaults.object(forKey: "popupSwipeThreshold") as? Int ?? 40

        if let data = defaults.data(forKey: "audioSources"),
           let sources = try? JSONDecoder().decode([AudioSource].self, from: data) {
            self.audioSources = sources
        } else {
            self.audioSources = [UserConfig.defaultAudioSource]
        }
        self.audioEnableAutoplay = defaults.object(forKey: "audioEnableAutoplay") as? Bool ?? false
        self.audioPlaybackMode = defaults.string(forKey: "audioPlaybackMode")
            .flatMap(AudioPlaybackMode.init) ?? .interrupt
        self.customCSS = defaults.string(forKey: "customCSS") ?? ""
    }
}
