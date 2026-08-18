//
//  PopupView.swift
//  Donguri
//
//  Ported from Hoshi Reader. Changes: sasayaki (audiobook sync) controls removed,
//  and the lookup-entry builder reads Swift-native types from LookupEngine
//  instead of converting from C++ std::string.
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI

struct PopupLayout {
    let selectionRect: CGRect
    let screenSize: CGSize
    let maxWidth: CGFloat
    let maxHeight: CGFloat
    let isVertical: Bool
    let isFullWidth: Bool
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    
    private let popupPadding: CGFloat = 4
    private let screenBorderPadding: CGFloat = 6
    
    private var spaceLeft: CGFloat {
        selectionRect.minX - popupPadding
    }
    
    private var spaceRight: CGFloat {
        screenSize.width - selectionRect.maxX - popupPadding
    }
    
    private var showOnRight: Bool {
        spaceRight >= spaceLeft || spaceRight >= maxWidth
    }
    
    private var spaceAbove: CGFloat {
        selectionRect.minY - topInset - popupPadding
    }
    
    private var spaceBelow: CGFloat {
        screenSize.height - bottomInset - selectionRect.maxY - popupPadding
    }
    
    private var showBelow: Bool {
        spaceBelow >= height
    }
    
    var width: CGFloat {
        if isFullWidth {
            return screenSize.width - screenBorderPadding * 2
        }
        
        if isVertical {
            return min(max(spaceLeft, spaceRight) - screenBorderPadding, maxWidth)
        }
        
        return min(screenSize.width - screenBorderPadding * 2, maxWidth)
    }
    
    var height: CGFloat {
        if isVertical || isFullWidth {
            return maxHeight
        }
        
        return min(max(spaceAbove, spaceBelow) - screenBorderPadding, maxHeight)
    }
    
    var position: CGPoint {
        var x: CGFloat
        var y: CGFloat
        
        if isFullWidth {
            x = width / 2 + screenBorderPadding
            y = screenSize.height - height / 2 - screenBorderPadding
        } else {
            if isVertical {
                if showOnRight {
                    x = selectionRect.maxX + popupPadding + (width / 2)
                } else {
                    x = selectionRect.minX - popupPadding - (width / 2)
                }
                x = max(width / 2, min(x, screenSize.width - width / 2))
                
                y = selectionRect.minY + (height / 2)
                y = max(height / 2 + screenBorderPadding + topInset, min(y, screenSize.height - bottomInset - height / 2 - screenBorderPadding))
            } else {
                x = selectionRect.minX + (width / 2)
                x = max(width / 2 + screenBorderPadding, min(x, screenSize.width - width / 2 - screenBorderPadding))
                
                if showBelow {
                    y = selectionRect.maxY + popupPadding + (height / 2)
                } else {
                    y = selectionRect.minY - popupPadding - (height / 2)
                }
                y = max(height / 2 + topInset + screenBorderPadding, min(y, screenSize.height - bottomInset - height / 2 - screenBorderPadding))
            }
        }
        return CGPoint(x: x, y: y)
    }
}

struct PopupView: View {
    @Environment(UserConfig.self) private var userConfig
    @Binding var isVisible: Bool
    let selectionData: SelectionData?
    let lookupResults: [LookupResult]
    let dictionaryStyles: [String: String]
    let screenSize: CGSize
    let isVertical: Bool
    let isFullWidth: Bool
    var topInset: CGFloat = 0
    var bottomInset: CGFloat = 0
    let coverURL: URL?
    let documentTitle: String?
    var clearSelection: Bool
    var onTextSelected: ((SelectionData) -> Int?)?
    var onTapOutside: (() -> Void)?
    var onSwipeDismiss: (() -> Void)?
    
    @State private var content: String = ""
    @State private var lookupEntries: [[String: Any]] = []
    @State private var controlsHeight: CGFloat = 0
    @State private var backCount: Int = 0
    @State private var forwardCount: Int = 0
    @State private var backTrigger: Bool = false
    @State private var forwardTrigger: Bool = false
    
    init(
        userConfig: UserConfig,
        isVisible: Binding<Bool>,
        selectionData: SelectionData?,
        lookupResults: [LookupResult],
        dictionaryStyles: [String: String],
        screenSize: CGSize,
        isVertical: Bool,
        isFullWidth: Bool,
        topInset: CGFloat = 0,
        bottomInset: CGFloat = 0,
        coverURL: URL?,
        documentTitle: String?,
        clearSelection: Bool,
        onTextSelected: ((SelectionData) -> Int?)? = nil,
        onTapOutside: (() -> Void)? = nil,
        onSwipeDismiss: (() -> Void)? = nil
    ) {
        _isVisible = isVisible
        self.selectionData = selectionData
        self.lookupResults = lookupResults
        self.dictionaryStyles = dictionaryStyles
        self.screenSize = screenSize
        self.isVertical = isVertical
        self.isFullWidth = isFullWidth
        self.topInset = topInset
        self.bottomInset = bottomInset
        self.coverURL = coverURL
        self.documentTitle = documentTitle
        self.clearSelection = clearSelection
        self.onTextSelected = onTextSelected
        self.onTapOutside = onTapOutside
        self.onSwipeDismiss = onSwipeDismiss
        
        let cache = Self.buildContent(lookupResults: lookupResults, userConfig: userConfig)
        _content = State(initialValue: cache.content)
        _lookupEntries = State(initialValue: cache.lookupEntries)
    }
    
    private var layout: PopupLayout? {
        guard let selectionData else {
            return nil
        }
        
        let result = PopupLayout(
            selectionRect: selectionData.rect,
            screenSize: screenSize,
            maxWidth: CGFloat(userConfig.popupWidth),
            maxHeight: CGFloat(userConfig.popupHeight),
            isVertical: isVertical,
            isFullWidth: isFullWidth,
            topInset: topInset,
            bottomInset: bottomInset
        )
        
        guard result.width.isFinite,
              result.height.isFinite,
              result.position.x.isFinite,
              result.position.y.isFinite else {
            return nil
        }
        
        return result
    }
    
    @ViewBuilder
    private var actionBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 24) {
                Button {
                    backTrigger.toggle()
                    backCount -= 1
                    forwardCount += 1
                } label: {
                    Image(systemName: "chevron.left")
                        .opacity(backCount > 0 ? 1 : 0.3)
                }
                .disabled(backCount == 0)
                
                Button {
                    forwardTrigger.toggle()
                    forwardCount -= 1
                    backCount += 1
                } label: {
                    Image(systemName: "chevron.right")
                        .opacity(forwardCount > 0 ? 1 : 0.3)
                }
                .disabled(forwardCount == 0)
                Spacer()
                Button {
                    onSwipeDismiss?()
                } label: {
                    Image(systemName: "xmark")
                }
            }
            .font(.body)
            .foregroundStyle(.secondary)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            Divider()
        }
    }
    
    private func popupContent(selectionData: SelectionData, layout: PopupLayout) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                if userConfig.popupActionBar || backCount > 0 || forwardCount > 0 {
                    actionBar
                }
            }
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                controlsHeight = $0
            }
            
            PopupWebView(
                content: content,
                position: CGPoint(x: layout.position.x - layout.width / 2, y: layout.position.y - layout.height / 2 + controlsHeight),
                scale: CGFloat(userConfig.popupScale),
                clearSelection: clearSelection,
                dictionaryStyles: dictionaryStyles,
                lookupEntries: lookupEntries,
                scanNonJapaneseText: userConfig.scanNonJapaneseText,
                scanLength: userConfig.scanLength,
                backTrigger: backTrigger,
                forwardTrigger: forwardTrigger,
                onMine: { content in
                    await mineEntry(content: content, sentence: selectionData.sentence)
                },
                onTextSelected: onTextSelected,
                onTapOutside: onTapOutside,
                onSwipeDismiss: onSwipeDismiss,
                onRedirect: { query in
                    let results = LookupEngine.shared.lookup(
                        query,
                        maxResults: userConfig.maxResults,
                        scanLength: userConfig.scanLength
                    )
                    let entries = Self.buildLookupEntries(lookupResults: results)
                    if !entries.isEmpty {
                        backCount += 1
                        forwardCount = 0
                    }
                    return entries
                }
            )
        }
        .frame(width: layout.width, height: layout.height)
    }
    
    var body: some View {
        if #available(iOS 26, *), !userConfig.popupDisableTransparency {
            GlassEffectContainer {
                if isVisible, let selectionData, let layout, !content.isEmpty {
                    popupContent(selectionData: selectionData, layout: layout)
                        .glassEffect(.regular, in: .rect(cornerRadius: 8))
                        .position(layout.position)
                }
            }
        } else {
            Group {
                if isVisible, let selectionData, let layout, !content.isEmpty {
                    popupContent(selectionData: selectionData, layout: layout)
                        .background(
                            userConfig.popupDisableTransparency ? AnyShapeStyle(Color(.systemBackground)) : AnyShapeStyle(.ultraThinMaterial),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.primary.opacity(0.2), lineWidth: 1))
                        .position(layout.position)
                }
            }
        }
    }
    
    private func mineEntry(content: [String: String], sentence: String) async -> Bool {
        await AnkiManager.shared.addNote(
            content: content,
            context: MiningContext(
                sentence: sentence,
                documentTitle: documentTitle,
                coverURL: coverURL
            )
        )
    }
    
    static func buildLookupEntries(lookupResults: [LookupResult]) -> [[String: Any]] {
        lookupResults.map { result in
            let glossaries = result.term.glossaries.map {
                [
                    "dictionary": $0.dictName,
                    "content": $0.glossary,
                    "definitionTags": $0.definitionTags,
                    "termTags": $0.termTags,
                ] as [String: Any]
            }

            let frequencies = result.term.frequencies.map { entry in
                [
                    "dictionary": entry.dictName,
                    "frequencies": entry.frequencies.map {
                        ["value": $0.value, "displayValue": $0.displayValue] as [String: Any]
                    },
                ] as [String: Any]
            }

            // `pitch_positions` became a richer `pitches` array upstream; the popup
            // JS still wants a flat, de-duplicated list of accent positions.
            let pitches = result.term.pitches.map { entry in
                var positions: [Int] = []
                for pitch in entry.pitches where !positions.contains(pitch.position) {
                    positions.append(pitch.position)
                }
                var transcriptions: [String] = []
                for transcription in entry.transcriptions where !transcriptions.contains(transcription) {
                    transcriptions.append(transcription)
                }
                return [
                    "dictionary": entry.dictName,
                    "pitchPositions": positions,
                    "transcriptions": transcriptions,
                ] as [String: Any]
            }

            return [
                "expression": result.term.expression,
                "reading": result.term.reading,
                "matched": result.matched,
                "deinflectionTrace": result.trace.reversed().map {
                    ["name": $0.name, "description": $0.description]
                },
                "glossaries": glossaries,
                "frequencies": frequencies,
                "pitches": pitches,
                "rules": result.term.rules.split(separator: " ").map(String.init),
            ] as [String: Any]
        }
    }

    private static func buildContent(lookupResults: [LookupResult], userConfig: UserConfig) -> (content: String, lookupEntries: [[String: Any]]) {
        let entries = buildLookupEntries(lookupResults: lookupResults)
        
        let collapsedDictionaries = userConfig.collapseMode == .custom
        ? ((try? JSONEncoder().encode(DictionaryManager.shared.collapsedDictionaries))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]") : "[]"
        let audioSources = (try? JSONEncoder().encode(userConfig.enabledAudioSources))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
        let scaledCSS = userConfig.customCSS.replacingOccurrences(of: #"(-?(?:\d+(?:\.\d+)?|\.\d+))px"#, with: "calc($1px * var(--popup-scale))", options: .regularExpression)
        let customCSS = (try? JSONSerialization.data(withJSONObject: scaledCSS, options: .fragmentsAllowed))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
        
        let content = """
        <script>
            window.collapseMode = "\(userConfig.collapseMode.rawValue)";
            window.expandFirstDictionary = \(userConfig.expandFirstDictionary);
            window.collapsedDictionaries = \(collapsedDictionaries);
            window.twoColumnLayout = \(userConfig.twoColumnLayout);
            window.compactGlossaries = \(userConfig.compactGlossaries);
            window.showExpressionTags = \(userConfig.showExpressionTags);
            window.harmonicFrequency = \(userConfig.harmonicFrequency);
            window.deduplicatePitchAccents = \(userConfig.deduplicatePitchAccents);
            window.compactPitchAccents = \(userConfig.compactPitchAccents);
            window.audioSources = \(audioSources);
            window.audioEnableAutoplay = \(userConfig.audioEnableAutoplay);
            window.audioPlaybackMode = "\(userConfig.audioPlaybackMode.rawValue)";
            window.needsAudio = \(AnkiManager.shared.needsAudio);
            window.allowDupes = \(AnkiManager.shared.allowDupes);
            window.useAnkiConnect = \(AnkiManager.shared.useAnkiConnect);
            window.embedMedia = \(AnkiManager.shared.embedMedia);
            window.compactGlossariesAnki = \(AnkiManager.shared.compactGlossaries);
            window.customCSS = \(customCSS);
            window.swipeThreshold = \(userConfig.popupSwipeToDismiss ? userConfig.popupSwipeThreshold : 0);
        </script>
        <div id="entries-container"></div>
        """
        
        return (content, entries)
    }
}
