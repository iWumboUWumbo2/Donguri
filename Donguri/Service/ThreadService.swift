//
//  ThreadService.swift
//  Donguri
//
//  Created by John Connery on 6/15/26.
//

import Foundation

struct ThreadService {
    func fetchThreads(boardURL: String) async throws -> [Thread] {
        guard let url = URL(string: "subject.txt",
                            relativeTo: URL(string: boardURL)) else {
            throw URLError(.badURL)
        }
                
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        guard let threadData = String(data: data, encoding: .shiftJIS) else {
            throw URLError(.cannotDecodeContentData)
        }
        
        let regex = #/(\d+)\.dat<>(.*)\((\d+)\)\s*$/#
        
        return threadData
            .components(separatedBy: .newlines)
            .compactMap { element in
                guard let match = element.wholeMatch(of: regex),
                      let id = Int(match.1),
                      let responseCount = Int(match.3) else {
                    if !element.isEmpty {
                        print("Error parsing: \(element)")
                    }
                    return nil
                }
                
                let title = String(match.2)
                    .trimmingCharacters(in: .whitespaces)
                    .htmlDecoded
                
                return Thread(id: id,
                              title: title,
                              responseCount: responseCount)
            }
    }
}
