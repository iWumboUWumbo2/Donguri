//
//  BBSMenuService.swift
//  Donguri
//
//  Created by John Connery on 6/14/26.
//

import Foundation

struct BBSMenuService {
    private let menuURL: URL = URL(string: "https://menu.5ch.io/bbsmenu.json")!

    func fetchBBSMenu() async throws -> BBSMenu {
        let (data, response) = try await URLSession.shared.data(from: menuURL)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try decoder.decode(BBSMenu.self, from: data)
    }
}
