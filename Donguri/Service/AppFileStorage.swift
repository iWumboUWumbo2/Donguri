//
//  AppFileStorage.swift
//  Donguri
//
//  Generic file storage helpers, trimmed from Hoshi Reader's BookStorage.swift
//  (book/EPUB-specific pieces dropped — Donguri only needs the app-support
//  directory + generic copy/save/load helpers for dictionaries and Anki config).
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import Foundation

struct AppFileStorage {
    nonisolated static func getAppDirectory() throws -> URL {
        guard let url = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AppFileStorageError.appDirectoryNotFound
        }
        if !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    @discardableResult
    static func copySecurityScopedFile(from fileURL: URL, to destinationPath: String? = nil) throws -> URL {
        guard fileURL.startAccessingSecurityScopedResource() else {
            throw AppFileStorageError.accessDenied
        }
        defer { fileURL.stopAccessingSecurityScopedResource() }

        let appDirectory = try getAppDirectory()
        let destinationURL = appDirectory.appendingPathComponent(destinationPath ?? fileURL.lastPathComponent)

        let destinationFolder = destinationURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: destinationFolder.path(percentEncoded: false)) {
            try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        }

        try replaceFile(at: destinationURL, with: fileURL)
        return destinationURL
    }

    @discardableResult
    static func copyFile(from fileURL: URL, to destinationPath: String) throws -> URL {
        let appDirectory = try getAppDirectory()
        let destinationURL = appDirectory.appendingPathComponent(destinationPath)

        if destinationURL.path(percentEncoded: false) == fileURL.path(percentEncoded: false) {
            return destinationURL
        }

        let destinationFolder = destinationURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: destinationFolder.path(percentEncoded: false)) {
            try FileManager.default.createDirectory(at: destinationFolder, withIntermediateDirectories: true)
        }

        try replaceFile(at: destinationURL, with: fileURL)
        return destinationURL
    }

    private static func replaceFile(at destination: URL, with source: URL) throws {
        try delete(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
    }

    static func delete(at url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else {
            return
        }
        try FileManager.default.removeItem(at: url)
    }

    static func save<T: Encodable>(_ object: T, inside directory: URL, as fileName: String) throws {
        let targetURL = directory.appendingPathComponent(fileName)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(object)

        try data.write(to: targetURL, options: .atomic)
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    nonisolated enum AppFileStorageError: LocalizedError {
        case accessDenied
        case appDirectoryNotFound

        var errorDescription: String? {
            switch self {
            case .accessDenied:
                return String(localized: "Could not access file")
            case .appDirectoryNotFound:
                return String(localized: "App directory not found")
            }
        }
    }
}
