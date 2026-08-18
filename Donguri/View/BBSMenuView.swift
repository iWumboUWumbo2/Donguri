//
//  BBSMenuView.swift
//  Donguri
//
//  Created by John Connery on 6/16/26.
//

import SwiftUI

struct BBSMenuView: View {
    @State private var menu: BBSMenu?
    @State private var errorMessage: String?
    @State private var showSettings = false
    @State private var showDictionarySearch = false

    var body: some View {
        NavigationStack {
            Group {
                if let menu {
                    MenuListView(menu: menu)
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
            .navigationTitle("５ちゃんねる")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showDictionarySearch = true
                    } label: {
                        Image(systemName: "character.book.closed.ja")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showDictionarySearch) {
                NavigationStack {
                    DictionarySearchView()
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button {
                                    showDictionarySearch = false
                                } label: {
                                    Image(systemName: "xmark")
                                }
                            }
                        }
                }
            }
        }
        .task {
            await loadMenu()
        }
        .refreshable {
            await loadMenu()
        }
    }

    private func loadMenu() async {
        do {
            errorMessage = nil
            let service = BBSMenuService()
            let newMenu = try await service.fetchBBSMenu()
            menu = newMenu
        } catch {
            errorMessage = "エラーが発生しました: \(error)"
            print("BBSMenuView Error: \(error)")
        }
    }
}

struct MenuListView: View {
    let menu: BBSMenu

    var body: some View {
        List {
            ForEach(menu.menuList) { category in
                CategoryDisclosureView(category: category)
            }
        }
        .listStyle(.insetGrouped)
    }
}


struct CategoryDisclosureView: View {
    let category: BBSMenu.MenuList

    var body: some View {
        DisclosureGroup {
            ForEach(category.categoryContent) { board in
                NavigationLink {
                    BoardView(board: board)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .foregroundStyle(Color.accentColor)
                        Text(board.boardName)
                            .foregroundStyle(.primary)
                    }
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(category.categoryName)
                    .font(.headline)
                Chip(text: "\(category.categoryTotal)", tint: .secondary, filled: false)
            }
        }
    }
}

#Preview {
    BBSMenuView()
}
