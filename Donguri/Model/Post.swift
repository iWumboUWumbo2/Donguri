//
//  Post.swift
//  Donguri
//
//  Created by John Connery on 6/15/26.
//

import Foundation

struct Post {
    let name: String
    let trip: String?
    let email: String
    let date: String
    let id: String?
    let text: String
    let threadTitle: String?

    /// Indices (into the thread's post array) of posts that reply to this one via `>>N`.
    let replies: [Int]?
}
