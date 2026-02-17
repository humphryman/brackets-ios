//
//  APIConfig.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import Foundation

/// Legacy API configuration - Use AppConfig.API instead
/// This file is maintained for backward compatibility
enum APIConfig {
    static var baseURL: String {
        AppConfig.API.baseURL
    }
    
    static var apiURL: String {
        AppConfig.API.apiURL
    }
}
