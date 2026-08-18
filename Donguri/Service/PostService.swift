//
//  PostService.swift
//  Donguri
//
//  Created by John Connery on 6/15/26.
//

import Foundation

struct PostService {
    private enum FetchError: Error {
        case datNotFound
    }

    func fetchPosts(boardURL: String, threadId: Int) async throws -> [Post] {
        do {
            return try await fetchFromDat(boardURL: boardURL, threadId: threadId)
        } catch FetchError.datNotFound {
            // The thread has "dat落ち" (aged out of the live dat store). Fall back
            // to parsing the server's own read.cgi HTML page, which keeps serving
            // old threads from its archive long after the raw .dat is gone.
            return try await fetchFromArchive(boardURL: boardURL, threadId: threadId)
        }
    }

    private func fetchFromDat(boardURL: String, threadId: Int) async throws -> [Post] {
        guard let url = URL(string: "dat/\(threadId).dat",
                            relativeTo: URL(string: boardURL)) else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        guard httpResponse.statusCode != 404 else {
            throw FetchError.datNotFound
        }
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let postData = String(data: data, encoding: .shiftJIS) else {
            throw URLError(.cannotDecodeRawData)
        }

        let regex = #/(.*?)<>(.*?)<>(.*?)(?:\s+ID:([^\s<>]+))?(?:\s+BE:([^\s<>]+))?<>(.*?)<>(.*)/#
        let abornMarker = "あぼーん"

        // First pass: parse each line into a post, without reply back-references
        // (those require knowing about every post first, and Post is immutable).
        let parsed = postData
            .components(separatedBy: .newlines)
            .compactMap { element -> Post? in
                // Skip empty lines
                guard !element.isEmpty else { return nil }

                // Skip aborn (deleted/moderated) posts
                if element.hasPrefix(abornMarker) { return nil }

                guard let match = element.wholeMatch(of: regex) else {
                    print("Error parsing: \(element)")
                    return nil
                }

                let name = String(match.1).htmlDecoded
                let email = String(match.2).htmlDecoded

                let text = String(match.6).htmlDecoded.replacing(#/>>(\d+)/#) { match in
                    "[>>\(match.1)](donguri://res/\(match.1))"
                }

                let threadTitle: String? = match.7.isEmpty ? nil :
                    String(match.7)
                        .components(separatedBy: "\t").first
                        .map { $0.trimmingCharacters(in: .whitespaces) }

                return Post(name: name,
                            trip: Self.extractTrip(from: name),
                            email: email,
                            date: String(match.3),
                            id: match.4.map(String.init),
                            text: text,
                            threadTitle: threadTitle,
                            replies: nil)
            }

        return Self.attachReplies(to: parsed)
    }

    /// Parses a thread's read.cgi HTML page — used once a thread's raw .dat has
    /// aged out of the live server (dat落ち), since the server still renders old
    /// threads as HTML long after the .dat itself is gone.
    private func fetchFromArchive(boardURL: String, threadId: Int) async throws -> [Post] {
        guard let boardURLComponents = URL(string: boardURL),
              let host = boardURLComponents.host else {
            throw URLError(.badURL)
        }
        let directoryName = boardURLComponents.pathComponents.first { $0 != "/" } ?? ""

        guard let url = URL(string: "https://\(host)/test/read.cgi/\(directoryName)/\(threadId)/") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        guard let html = String(data: data, encoding: .shiftJIS) else {
            throw URLError(.cannotDecodeRawData)
        }

        let title = html.firstMatch(of: #/<title>(.*?)<\/title>/#.dotMatchesNewlines())
            .map { String($0.1).trimmingCharacters(in: .whitespacesAndNewlines) }

        // Each post is a <div id="N" data-date="…" data-userid="ID:xxxx" data-id="N"
        // class="clear post"> …</div>; scanning for just the start markers and
        // slicing between consecutive ones avoids needing to balance nested tags.
        let postStartRegex = #/<div id="\d+" data-date="[^"]*" data-userid="([^"]*)" data-id="\d+" class="clear post">/#
        let starts = Array(html.matches(of: postStartRegex))

        let parsed: [Post] = starts.enumerated().compactMap { index, match in
            let chunkStart = match.range.upperBound
            let chunkEnd = index + 1 < starts.count ? starts[index + 1].range.lowerBound : html.endIndex
            let chunk = html[chunkStart..<chunkEnd]

            guard let nameMatch = chunk.firstMatch(of: #/<span class="postusername">(.*?)<\/span>/#),
                  let dateMatch = chunk.firstMatch(of: #/<span class="date">(.*?)<\/span>/#),
                  let contentMatch = chunk.firstMatch(of: #/<div class="post-content">(.*?)<\/div>/#) else {
                print("Error parsing archive post at index \(index)")
                return nil
            }

            let name = String(nameMatch.1).htmlDecoded

            let rawUserID = String(match.1)
            let id: String? = rawUserID.hasPrefix("ID:") ? String(rawUserID.dropFirst(3)) :
                (rawUserID.isEmpty ? nil : rawUserID)

            let text = String(contentMatch.1).htmlDecoded.replacing(#/>>(\d+)/#) { m in
                "[>>\(m.1)](donguri://res/\(m.1))"
            }

            return Post(name: name,
                        trip: Self.extractTrip(from: name),
                        email: "",
                        date: String(dateMatch.1).htmlDecoded,
                        id: id,
                        text: text,
                        threadTitle: index == 0 ? title : nil,
                        replies: nil)
        }

        return Self.attachReplies(to: parsed)
    }

    /// A tripcode only exists if "◆" actually appears in the name — `split` alone
    /// returns the whole string as a single element when the separator is absent,
    /// so without this check every plain anonymous name would be misread as its
    /// own "tripcode".
    private static func extractTrip(from name: String) -> String? {
        let components = name.components(separatedBy: "◆")
        guard components.count > 1 else { return nil }
        return components.last?.split(separator: " ").first.map(String.init)
    }

    /// Second pass: figure out which posts reply to which via >>N, then rebuild
    /// the posts with `replies` populated (Post is immutable, so this can't be
    /// done in place during the first pass).
    private static func attachReplies(to posts: [Post]) -> [Post] {
        var repliesByIndex: [Int: [Int]] = [:]
        for (i, post) in posts.enumerated() {
            for match in post.text.matches(of: #/>>(\d+)/#) {
                guard let n = Int(match.1) else { continue }
                let targetIndex = n - 1
                guard posts.indices.contains(targetIndex) else { continue }
                repliesByIndex[targetIndex, default: []].append(i)
            }
        }

        return posts.enumerated().map { index, post in
            Post(name: post.name,
                 trip: post.trip,
                 email: post.email,
                 date: post.date,
                 id: post.id,
                 text: post.text,
                 threadTitle: post.threadTitle,
                 replies: repliesByIndex[index])
        }
    }
}
