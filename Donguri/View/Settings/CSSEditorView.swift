//
//  CSSEditorView.swift
//  Donguri
//
//  Ported from Hoshi Reader. The font menu (FontManager) is dropped since
//  Donguri has no font import, and SwiftUIIntrospect is replaced with a
//  UITextView-free TextEditor.
//
//  Copyright © 2026 Manhhao.
//  SPDX-License-Identifier: GPL-3.0-or-later
//

import SwiftUI

struct CSSEditorView: View {
    let dictionaryManager = DictionaryManager.shared
    @Binding var text: String
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            TextEditor(text: $text)
                .font(.system(.body, design: .monospaced))
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isFocused)
        }
    }
    
    private var toolbar: some View {
        HStack {
            dictionaryMenu
                .conditionalGlassEffect()
            Spacer()
            if isFocused {
                Button {
                    isFocused = false
                } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 20))
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .conditionalGlassEffect()
            }
        }
        .padding(8)
    }
    
    private var dictionaryMenu: some View {
        Menu {
            ForEach(dictionaryManager.termDictionaries) { dict in
                Button(dict.index.title) {
                    insertText("""
                    [data-dictionary="\(dict.index.title)"] {
                        
                    }
                    
                    """)
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "character.book.closed.ja")
                Text("Selector")
            }
            .font(.system(size: 16))
            .foregroundStyle(.primary)
            .frame(height: 44)
            .padding(.horizontal, 12)
        }
        .buttonStyle(.plain)
    }
    
    private func insertText(_ insertedText: String) {
        text += insertedText
    }
}
