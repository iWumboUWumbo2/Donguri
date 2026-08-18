//
//  BBSMenu.swift
//  Donguri
//
//  Created by John Connery on 6/14/26.
//

import Foundation

struct BBSMenu: Decodable {
    let description: String
    let menuList: [MenuList]
    let lastModify: Int
    let lastModifyString: String

    struct MenuList: Decodable, Identifiable {
        let categoryName: String
        let categoryNumber: String
        let categoryTotal: Int
        let categoryContent: [CategoryContent]
        
        var id: String { categoryNumber }
    }

    struct CategoryContent: Decodable, Identifiable {
        let categoryOrder: Int
        let boardName: String
        let url: String
        let directoryName: String
        let category: Int
        let categoryName: String
        
        var id: Int { categoryOrder }
    }
}

