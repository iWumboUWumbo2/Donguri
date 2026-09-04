//
//  NGFilterView.swift
//  Donguri
//
//  Created by John Connery on 9/3/26.
//

import SwiftUI

struct NGFilterView: View {
    @State private var store = NGFilterStore.shared
    @State private var newKind: NGRule.Kind = .word
    @State private var newPattern: String = ""
    @FocusState private var patternFocused: Bool

    private var rulesByKind: [(kind: NGRule.Kind, rules: [NGRule])] {
        NGRule.Kind.allCases.compactMap { kind in
            let matching = store.rules.filter { $0.kind == kind }
            return matching.isEmpty ? nil : (kind, matching)
        }
    }

    var body: some View {
        List {
            Section {
                Picker("種類", selection: $newKind) {
                    ForEach(NGRule.Kind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                HStack {
                    TextField("追加する語句", text: $newPattern)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($patternFocused)
                        .onSubmit(addRule)

                    Button(action: addRule) {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(newPattern.trimmingCharacters(in: .whitespaces).isEmpty
                                     ? Color.secondary : Color.accentColor)
                    .disabled(newPattern.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            } header: {
                Text("追加")
            } footer: {
                Text("一致する書き込みは「あぼーん」として非表示になります。レス番号は変わりません。")
            }

            if rulesByKind.isEmpty {
                Section {
                    Text("NG設定はありません")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(rulesByKind, id: \.kind) { group in
                    Section {
                        ForEach(group.rules) { rule in
                            Text(rule.pattern)
                                .lineLimit(2)
                        }
                        .onDelete { offsets in
                            // Offsets are within this section — map back to the store.
                            let ids = offsets.map { group.rules[$0].id }
                            let indices = IndexSet(store.rules.indices.filter { ids.contains(store.rules[$0].id) })
                            store.remove(atOffsets: indices)
                        }
                    } header: {
                        Text(group.kind.label)
                    }
                }
            }
        }
        .navigationTitle("NG設定")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
    }

    private func addRule() {
        store.add(kind: newKind, pattern: newPattern)
        newPattern = ""
        patternFocused = true
    }
}

#Preview {
    NavigationStack {
        NGFilterView()
    }
}
