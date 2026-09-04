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
    @State private var searchText: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if let menu {
                    MenuListView(menu: menu, searchText: searchText)
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
        .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "フィルタ"
                )
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
    let searchText: String

    var filteredMenuList: [BBSMenu.MenuList] {
        guard !searchText.isEmpty else { return menu.menuList }
        return menu.menuList.filter {
            $0.categoryContent.contains(where: { $0.boardName.localizedCaseInsensitiveContains(searchText) })
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredMenuList) { category in
                CategoryDisclosureView(category: category, searchText: searchText)
            }
        }
        .listStyle(.insetGrouped)
    }
}


struct CategoryDisclosureView: View {
    let category: BBSMenu.MenuList
    let searchText: String
    
    var filteredCategoryContent: [BBSMenu.CategoryContent] {
        guard !searchText.isEmpty else { return category.categoryContent }
        return category.categoryContent.filter {
            $0.boardName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        DisclosureGroup() {
            ForEach(filteredCategoryContent) { board in
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
