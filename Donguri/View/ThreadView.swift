//
//  ThreadView.swift
//  Donguri
//
//  Created by John Connery on 6/16/26.
//

import SwiftUI

struct ThreadRoute: Hashable {
    let boardURL: String
    let threadId: Int
}

struct ThreadView: View {
    var thread: Thread?
    var boardURL: String?

    @State private var posts: [Post] = []
    @State private var errorMessage: String?

    @State private var threadRoute: ThreadRoute?
    @State private var postReplyIndex: Int?

    // ID/trip → post indices, used to highlight every post from the same poster.
    @State private var idIndices: [String: [Int]] = [:]
    @State private var tripIndices: [String: [Int]] = [:]
    @State private var highlightedID: String?
    @State private var highlightedTrip: String?

    private var highlightedIndices: Set<Int> {
        if let highlightedID {
            return Set(idIndices[highlightedID] ?? [])
        }
        if let highlightedTrip {
            return Set(tripIndices[highlightedTrip] ?? [])
        }
        return []
    }

    var body: some View {
        if let thread, let boardURL {
            Group {
                if !posts.isEmpty {
                    ZStack(alignment: .top) {
                        List {
                            ForEach(Array(posts.enumerated()), id: \.offset) { index, post in
                                PostView(index: index,
                                         post: post,
                                         idCount: post.id.flatMap { idIndices[$0]?.count } ?? 0,
                                         tripCount: post.trip.flatMap { tripIndices[$0]?.count } ?? 0,
                                         isIDHighlighted: post.id != nil && post.id == highlightedID,
                                         isTripHighlighted: post.trip != nil && post.trip == highlightedTrip,
                                         isHighlighted: highlightedIndices.contains(index),
                                         onThreadRoute: { route in
                                    threadRoute = route
                                }, onPostReply: { postIndex in
                                    postReplyIndex = postIndex
                                }, onIDTap: { id in
                                    toggleHighlightedID(id)
                                }, onTripTap: { trip in
                                    toggleHighlightedTrip(trip)
                                })
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 5, leading: 12, bottom: 5, trailing: 12))
                            }
                        }
                        .safeAreaInset(edge: .top) {
                            if let banner = highlightBannerText {
                                HighlightBanner(text: banner) {
                                    clearHighlight()
                                }
                                .padding(.top, 6)
                            }
                        }

                        // >>N popup overlay
                        if let replyIndex = postReplyIndex,
                           posts.indices.contains(replyIndex) {
                            // Dim layer — also the tap-to-dismiss target
                            Color.black.opacity(0.25)
                                .ignoresSafeArea()
                                .onTapGesture { postReplyIndex = nil }

                            PostView(index: replyIndex,
                                     post: posts[replyIndex],
                                     idCount: posts[replyIndex].id.flatMap { idIndices[$0]?.count } ?? 0,
                                     tripCount: posts[replyIndex].trip.flatMap { tripIndices[$0]?.count } ?? 0,
                                     isIDHighlighted: false,
                                     isTripHighlighted: false,
                                     isHighlighted: false,
                                     onThreadRoute: { route in
                                postReplyIndex = nil
                                threadRoute = route
                            }, onPostReply: { postIndex in
                                postReplyIndex = postIndex
                            }, onIDTap: { _ in }, onTripTap: { _ in })
                            .padding()
                            .cardBackground(cornerRadius: 14)
                            .padding(.horizontal)
                        }
                    }
                    .animation(.snappy, value: postReplyIndex)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("エラーが発生しました", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(errorMessage)
                    }
                } else {
                    ProgressView("しばらくお待ちください...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle(thread.title ?? posts.first?.threadTitle ?? "無題")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $threadRoute) { route in
                ThreadView(
                    thread: Thread(id: route.threadId, title: nil, responseCount: -1),
                    boardURL: route.boardURL
                )
            }
            .task {
                await loadThread(boardURL: boardURL, threadId: thread.id)
            }
            .refreshable {
                await loadThread(boardURL: boardURL, threadId: thread.id)
            }
        } else {
            ContentUnavailableView("エラー：スレや板情報がありません", systemImage: "exclamationmark.triangle")
        }
    }

    private var highlightBannerText: String? {
        if let highlightedID {
            let count = idIndices[highlightedID]?.count ?? 0
            return "ID:\(highlightedID) の書き込み: \(count)件"
        }
        if let highlightedTrip {
            let count = tripIndices[highlightedTrip]?.count ?? 0
            return "◆\(highlightedTrip) の書き込み: \(count)件"
        }
        return nil
    }

    private func toggleHighlightedID(_ id: String) {
        highlightedTrip = nil
        highlightedID = (highlightedID == id) ? nil : id
    }

    private func toggleHighlightedTrip(_ trip: String) {
        highlightedID = nil
        highlightedTrip = (highlightedTrip == trip) ? nil : trip
    }

    private func clearHighlight() {
        highlightedID = nil
        highlightedTrip = nil
    }

    public func loadThread(boardURL: String, threadId: Int) async {
        do {
            errorMessage = nil
            let service = PostService()
            let newPosts = try await service.fetchPosts(boardURL: boardURL, threadId: threadId)
            posts = newPosts
            (idIndices, tripIndices) = Self.buildHighlightIndices(posts: newPosts)
            highlightedID = nil
            highlightedTrip = nil
        } catch {
            errorMessage = "エラーが発生しました: \(error)"
            print("ThreadView Error: \(error)")
        }
    }

    private static func buildHighlightIndices(posts: [Post]) -> (id: [String: [Int]], trip: [String: [Int]]) {
        var byID: [String: [Int]] = [:]
        var byTrip: [String: [Int]] = [:]
        for (index, post) in posts.enumerated() {
            if let id = post.id {
                byID[id, default: []].append(index)
            }
            if let trip = post.trip {
                byTrip[trip, default: []].append(index)
            }
        }
        return (byID, byTrip)
    }
}

private struct HighlightBanner: View {
    let text: String
    let onClear: () -> Void

    var body: some View {
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Text(text)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .cardBackground(cornerRadius: 20)

            Spacer(minLength: 0)
        }
    }
}

struct PostView: View {
    var index: Int
    var post: Post

    var idCount: Int
    var tripCount: Int
    var isIDHighlighted: Bool
    var isTripHighlighted: Bool
    var isHighlighted: Bool = false

    var onThreadRoute: (ThreadRoute) -> Void
    var onPostReply: (Int) -> Void
    var onIDTap: (String) -> Void
    var onTripTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text("\(index + 1)")
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(Color.accentColor)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(Circle().fill(Color.accentColor.opacity(0.14)))

                if let replies = post.replies, !replies.isEmpty {
                    Chip(text: "\(replies.count)", systemImage: "message.fill", tint: .secondary, filled: false)
                }

                nameView
            }

            // .init makes it an AttributedString, allowing hyperlinks to be clickable
            Text(.init(post.text))
                .lineSpacing(4)
                .environment(\.openURL, OpenURLAction { url in
                    // Same-thread reply anchor (>>N)
                    if url.scheme == "donguri", url.host == "res",
                       let number = Int(url.lastPathComponent), number >= 1 {
                        onPostReply(number - 1)
                        return .handled
                    }

                    // Link to another 5ch thread
                    if let route = parseThreadLink(url: url) {
                        onThreadRoute(route)
                        return .handled
                    }

                    // Everything else → in-app Safari
                    guard url.scheme == "http" || url.scheme == "https" else {
                        return .systemAction   // no prefersInApp → iOS routes it normally
                    }
                    return .systemAction(prefersInApp: true)
                })

            HStack {
                Text(post.date)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Spacer()

                if let id = post.id {
                    Button {
                        onIDTap(id)
                    } label: {
                        Chip(text: idCount > 1 ? "ID:\(id)(\(idCount))" : "ID:\(id)",
                             tint: isIDHighlighted ? .accentColor : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .cardBackground(cornerRadius: 10, fill: Color(.secondarySystemGroupedBackground))
        .overlay {
            if isHighlighted {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Color.accentColor, lineWidth: 1.5)
            }
        }
    }

    @ViewBuilder
    private var nameView: some View {
        let label = post.name + " " + (!post.email.isEmpty ? "[\(post.email)]" : "")

        if let trip = post.trip {
            Button {
                onTripTap(trip)
            } label: {
                Text(.init(label))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(isTripHighlighted ? Color.accentColor : Color.primary)
            }
            .buttonStyle(.plain)
        } else {
            Text(.init(label))
                .font(.caption.weight(.medium))
                .foregroundStyle(.primary)
        }
    }

    private func parseThreadLink(url: URL) -> ThreadRoute? {
        guard let host = url.host, host.contains(".5ch.") else {
            return nil
        }

        let components = url.pathComponents

        guard let cgiIndex = components.firstIndex(of: "read.cgi"),
              components.count > cgiIndex + 2,
              let threadId = Int(components[cgiIndex + 2]) else {
            return nil
        }
        let directoryName = components[cgiIndex + 1]
        let boardURL = "https://\(host)/\(directoryName)/"

        return ThreadRoute(boardURL: boardURL, threadId: threadId)
    }
}

#Preview {
    ThreadView(thread: nil, boardURL: nil)
}
