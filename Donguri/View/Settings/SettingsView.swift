//
//  SettingsView.swift
//  Donguri
//
//  Created by John Connery on 8/18/26.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DictionaryView()
                    } label: {
                        Label("辞書", systemImage: "character.book.closed.ja")
                    }
                    NavigationLink {
                        AnkiView()
                    } label: {
                        Label("Anki", systemImage: "rectangle.on.rectangle.angled")
                    }
                } header: {
                    Text("辞書とマイニング")
                }
            }
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
