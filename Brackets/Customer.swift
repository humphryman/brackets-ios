//
//  Customer.swift
//  Brackets
//
//  Created by Humberto on 06/03/26.
//

import Foundation

struct Customer: Identifiable, Codable, Sendable {
    let id: Int
    let name: String
    let url: String
    let description: String?
    let sport: String?
    let logoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, name, url, description, sport
        case logoUrl = "logo_url"
    }
}
