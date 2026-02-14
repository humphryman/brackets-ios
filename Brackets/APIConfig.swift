//
//  APIConfig.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import Foundation

enum APIConfig {
    private static var isProduction: Bool {
        #if DEBUG
        return false
        #else
        return true
        #endif
    }
    
    static var baseURL: String {
        if isProduction {
            // TODO: Replace with your production API URL
            return "https://api.yourapp.com"
        } else {
            return "http://127.0.0.1:3000"
        }
    }
    
    static var apiURL: String {
        "\(baseURL)/api"
    }
}
