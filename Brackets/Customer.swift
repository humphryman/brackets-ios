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
    let status: String?

    enum CodingKeys: String, CodingKey {
        case id, name, url, description, sport, status
        case logoUrl = "logo_url"
    }

    /// Past leagues are flagged by the API's `status` field. Anything that
    /// isn't explicitly `"past"` (including a missing status) is treated as active.
    var isPast: Bool {
        status?.lowercased() == "past"
    }
}
