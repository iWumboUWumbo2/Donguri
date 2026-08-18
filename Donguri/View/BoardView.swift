//
//  BoardView.swift
//  Donguri
//
//  Created by John Connery on 6/16/26.
//

import SwiftUI

struct BoardView: View {
    var board: BBSMenu.CategoryContent?

    @State private var threads: [Thread] = []
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            if let board {
                Group {
                    if !threads.isEmpty {
                        List(threads) { thread in
                            NavigationLink {
                                ThreadView(thread: thread, boardURL: board.url)
                            } label: {
                                ThreadRowView(thread: thread)
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.plain)

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
                .navigationTitle(board.boardName)
                .navigationBarTitleDisplayMode(.inline)
                .task {
                    await loadBoard(board: board)
                }
                .refreshable {
                    await loadBoard(board: board)
                }
            } else {
                ContentUnavailableView("エラー：板情報がありません", systemImage: "exclamationmark.triangle")
            }
        }
    }
    
    private func loadBoard(board: BBSMenu.CategoryContent) async {
        do {
            errorMessage = nil
            let service = ThreadService()
            let newThreads = try await service.fetchThreads(boardURL: board.url)
            threads = newThreads
        } catch {
            errorMessage = "エラーが発生しました: \(error)"
            print("BoardView Error: \(error)")
        }
    }
}

struct ThreadRowView: View {
    let thread: Thread

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(thread.title ?? "無題")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                    Text(
                        Date(timeIntervalSince1970: TimeInterval(thread.id))
                            .formatted(date: .numeric, time: .shortened)
                    )
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Chip(text: "\(thread.responseCount)", systemImage: "message.fill")
       }
    }
}

#Preview {
    BoardView(board: nil)
}
