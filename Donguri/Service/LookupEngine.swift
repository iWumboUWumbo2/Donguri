//
//  LookupEngine.swift
//  Donguri
//
//  Wraps hoshidicts' C API (hoshidicts_c.h). Hoshi Reader drives the C++ API
//  directly, but that requires Swift to import `DictionaryQuery` — a class whose
//  `std::vector<Dictionary>` member is move-only, which the Swift C++ importer
//  can't synthesize a copy for. The C bindings hand out opaque pointers instead,
//  so Swift never needs that layout. Results are copied into Swift value types
//  here because the C results are freed as soon as the call returns.
//
//  Ported from Hoshi Reader.
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation
import CHoshiDicts

// MARK: - Swift mirrors of the C result structs

struct Frequency {
    let value: Int
    let displayValue: String
}

struct FrequencyEntry {
    let dictName: String
    let frequencies: [Frequency]
}

struct Pitch {
    let position: Int
    let pattern: String
    let nasal: [Int]
    let devoice: [Int]
}

struct PitchEntry {
    let dictName: String
    let pitches: [Pitch]
    let transcriptions: [String]
}

struct GlossaryEntry {
    let dictName: String
    let glossary: String
    let definitionTags: String
    let termTags: String
}

struct TermResult {
    let expression: String
    let reading: String
    let rules: String
    let score: Int
    let glossaries: [GlossaryEntry]
    let frequencies: [FrequencyEntry]
    let pitches: [PitchEntry]
}

struct TransformGroup {
    let name: String
    let description: String
}

struct LookupResult {
    let matched: String
    let deinflected: String
    let trace: [TransformGroup]
    let term: TermResult
}

struct DictionaryStyle {
    let dictName: String
    let styles: String
}

// MARK: - Conversion helpers

private func swiftString(_ s: hd_str) -> String {
    guard let ptr = s.ptr, s.len > 0 else { return "" }
    return String(decoding: UnsafeRawBufferPointer(start: ptr, count: s.len), as: UTF8.self)
}

private func buffer<T>(_ ptr: UnsafePointer<T>?, _ count: Int) -> UnsafeBufferPointer<T> {
    UnsafeBufferPointer(start: count > 0 ? ptr : nil, count: count)
}

private func convert(_ c: hd_term_result) -> TermResult {
    let glossaries = buffer(c.glossaries, c.glossaries_count).map {
        GlossaryEntry(
            dictName: swiftString($0.dict_name),
            glossary: swiftString($0.glossary),
            definitionTags: swiftString($0.definition_tags),
            termTags: swiftString($0.term_tags)
        )
    }

    let frequencies = buffer(c.frequencies, c.frequencies_count).map { entry in
        FrequencyEntry(
            dictName: swiftString(entry.dict_name),
            frequencies: buffer(entry.frequencies, entry.frequencies_count).map {
                Frequency(value: Int($0.value), displayValue: swiftString($0.display_value))
            }
        )
    }

    let pitches = buffer(c.pitches, c.pitches_count).map { entry in
        PitchEntry(
            dictName: swiftString(entry.dict_name),
            pitches: buffer(entry.pitches, entry.pitches_count).map { pitch in
                Pitch(
                    position: Int(pitch.position),
                    pattern: swiftString(pitch.pattern),
                    nasal: buffer(pitch.nasal, pitch.nasal_count).map(Int.init),
                    devoice: buffer(pitch.devoice, pitch.devoice_count).map(Int.init)
                )
            },
            transcriptions: buffer(entry.transcriptions, entry.transcriptions_count).map(swiftString)
        )
    }

    return TermResult(
        expression: swiftString(c.expression),
        reading: swiftString(c.reading),
        rules: swiftString(c.rules),
        score: Int(c.score),
        glossaries: glossaries,
        frequencies: frequencies,
        pitches: pitches
    )
}

// MARK: - Engine

final class LookupEngine {
    static let shared = LookupEngine()

    /// Owns the C handles for one set of loaded dictionaries. Rebuilt wholesale
    /// whenever the enabled dictionaries change.
    private nonisolated final class Bundle: @unchecked Sendable {
        let query: OpaquePointer
        let deinflector: OpaquePointer
        let lookup: OpaquePointer

        init?(termPaths: [URL], freqPaths: [URL], pitchPaths: [URL]) {
            guard let query = hd_query_new(),
                  let deinflector = hd_deinflector_new() else {
                return nil
            }

            for path in termPaths {
                _ = hd_query_add_term_dict(query, path.path(percentEncoded: false))
            }
            for path in freqPaths {
                _ = hd_query_add_freq_dict(query, path.path(percentEncoded: false))
            }
            for path in pitchPaths {
                _ = hd_query_add_pitch_dict(query, path.path(percentEncoded: false))
            }

            guard let lookup = hd_lookup_new(query, deinflector) else {
                hd_deinflector_free(deinflector)
                hd_query_free(query)
                return nil
            }

            self.query = query
            self.deinflector = deinflector
            self.lookup = lookup
        }

        deinit {
            hd_lookup_free(lookup)
            hd_deinflector_free(deinflector)
            hd_query_free(query)
        }
    }

    private var bundle: Bundle?
    private var generation = 0

    private init() {}

    func buildQuery(termPaths: [URL], freqPaths: [URL], pitchPaths: [URL]) {
        generation += 1
        let token = generation
        Task.detached(priority: .userInitiated) {
            let newBundle = Bundle(termPaths: termPaths, freqPaths: freqPaths, pitchPaths: pitchPaths)
            await MainActor.run {
                guard token == self.generation else { return }
                self.bundle = newBundle
            }
        }
    }

    func lookup(_ str: String, maxResults: Int = 16, scanLength: Int = 16) -> [LookupResult] {
        guard let bundle else { return [] }

        var out: UnsafePointer<hd_lookup_result>?
        var count: Int = 0
        guard let handle = hd_lookup_run(bundle.lookup, str, Int32(maxResults), scanLength, &out, &count) else {
            return []
        }
        defer { hd_lookup_results_free(handle) }

        return buffer(out, count).map { result in
            LookupResult(
                matched: swiftString(result.matched),
                deinflected: swiftString(result.deinflected),
                trace: buffer(result.trace, result.trace_count).map {
                    TransformGroup(name: swiftString($0.name), description: swiftString($0.description))
                },
                term: convert(result.term)
            )
        }
    }

    func getStyles() -> [DictionaryStyle] {
        guard let bundle else { return [] }

        var out: UnsafePointer<hd_dictionary_style>?
        var count: Int = 0
        guard let handle = hd_query_get_styles(bundle.query, &out, &count) else {
            return []
        }
        defer { hd_styles_free(handle) }

        return buffer(out, count).map {
            DictionaryStyle(dictName: swiftString($0.dict_name), styles: swiftString($0.styles))
        }
    }

    func withMediaFile<T>(dictName: String, mediaPath: String, _ body: (Data) -> T) -> T {
        guard let bundle else { return body(Data()) }
        let file = hd_query_get_media_file(bundle.query, dictName, mediaPath)
        guard file.size > 0, let ptr = file.data else {
            return body(Data())
        }
        let data = Data(bytesNoCopy: UnsafeMutableRawPointer(mutating: ptr), count: file.size, deallocator: .none)
        return body(data)
    }

    func getMediaFile(dictName: String, mediaPath: String) -> Data {
        withMediaFile(dictName: dictName, mediaPath: mediaPath) { Data($0) }
    }
}

// MARK: - Importer

nonisolated enum DictionaryImporter {
    struct Result {
        let success: Bool
        let title: String
        let termCount: Int
        let freqCount: Int
        let pitchCount: Int
        let error: String
    }

    static func `import`(zipPath: String, outputDir: String) -> Result {
        guard let handle = hd_import(zipPath, outputDir, 0) else {
            return Result(success: false, title: "", termCount: 0, freqCount: 0, pitchCount: 0,
                          error: "import failed")
        }
        defer { hd_import_result_free(handle) }

        return Result(
            success: hd_import_result_success(handle) != 0,
            title: hd_import_result_title(handle).map(String.init(cString:)) ?? "",
            termCount: Int(hd_import_result_term_count(handle)),
            freqCount: Int(hd_import_result_freq_count(handle)),
            pitchCount: Int(hd_import_result_pitch_count(handle)),
            error: hd_import_result_error(handle).map(String.init(cString:)) ?? ""
        )
    }
}
