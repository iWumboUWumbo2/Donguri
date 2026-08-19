//
//  DonguriApp.swift
//  Donguri
//
//  Created by John Connery on 6/14/26.
//

import SwiftUI

@main
struct DonguriApp: App {
    @State private var userConfig = UserConfig()
    // Instantiated at launch (not lazily on first settings visit) so the
    // dictionaries are loaded into LookupEngine before any post is tapped.
    @State private var dictionaryManager = DictionaryManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(userConfig)
                .task {
                    if userConfig.autoUpdateDictionaries {
                        dictionaryManager.autoUpdateDictionaries()
                    }
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }

    /// AnkiMobile hands control back via the `donguri://` x-callback-url scheme
    /// registered in Donguri-Info.plist. `AnkiManager` builds these URLs when it
    /// opens Anki; this is the other half of that round trip.
    private func handleURL(_ url: URL) {
        guard url.scheme == "donguri" else { return }

        switch url.host {
        case "ankiFetch":
            // Anki has written decks/notetypes to the pasteboard for us to read.
            AnkiManager.shared.fetch()
        case "ankiSuccess":
            if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
               let expression = components.queryItems?.first(where: { $0.name == "expression" })?.value {
                AnkiManager.shared.addWord(expression)
            }
        default:
            break
        }
    }
}
