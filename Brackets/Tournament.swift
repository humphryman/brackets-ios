//
//  Tournament.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import Foundation

struct Tournament: Identifiable, Codable {
    let id: Int
    let name: String
    let gender: Gender
    let teamCount: Int?
    let image: String?
    
    // Default team count to 0 if not provided
    var displayTeamCount: Int {
        teamCount ?? 0
    }
    
    // Full image URL combining base URL with the path from JSON
    var fullImageURL: String? {
        guard let image = image else { return nil }
        
        // If it's already a full URL (starts with http), return as is
        if image.lowercased().hasPrefix("http://") || image.lowercased().hasPrefix("https://") {
            return image
        }
        
        // Otherwise, combine with base URL
        // Remove any leading slash from image path to avoid double slashes
        let imagePath = image.hasPrefix("/") ? String(image.dropFirst()) : image
        return "\(APIConfig.baseURL)/\(imagePath)"
    }
}

enum Gender: Int, Codable, CaseIterable {
    case male = 0
    case female = 1
    
    var displayName: String {
        switch self {
        case .male:
            return "Varonil"
        case .female:
            return "Femenil"
        }
    }
}
