//
//  APIService.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import Foundation

enum APIError: Error {
    case invalidURL
    case invalidResponse
    case decodingError(Error)
    case networkError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        }
    }
}

// Response wrapper for when API returns { "tournaments": [...] }
struct TournamentsResponse: Codable {
    let tournaments: [Tournament]
}

// Response wrapper for standings
struct StandingsResponse: Codable {
    let standings: [TeamStanding]
}

// Team Standing Model
struct TeamStanding: Identifiable, Codable {
    let id: Int
    let teamName: String
    let total: Int
    let wins: Int
    let losses: Int
    let pointsFor: Int
    let pointsAgainst: Int
    let tie: Int
    let avg: Int
    let tieBreaker: String
    let teamLogo: String?
    
    // Computed property for point differential
    var pointDifferential: Int {
        pointsFor - pointsAgainst
    }
    
    // Record string (e.g., "5-2")
    var record: String {
        "\(wins)-\(losses)"
    }
    
    // Full image URL
    var fullImageURL: String? {
        guard let teamLogo = teamLogo else { return nil }
        
        if teamLogo.lowercased().hasPrefix("http://") || teamLogo.lowercased().hasPrefix("https://") {
            return teamLogo
        }
        
        let imagePath = teamLogo.hasPrefix("/") ? String(teamLogo.dropFirst()) : teamLogo
        return "\(APIConfig.baseURL)/\(imagePath)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id = "team_season_id"
        case teamName = "name"
        case total
        case wins = "won"
        case losses = "lost"
        case pointsFor = "favor"
        case pointsAgainst = "against"
        case tie
        case avg
        case tieBreaker = "tie_breaker"
        case teamLogo = "team_logo"
    }
}

actor APIService {
    static let shared = APIService()
    
    private init() {}
    
    func fetchTournaments() async throws -> [Tournament] {
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments.json") else {
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            // Debug: Print the raw JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Raw JSON Response:")
                print(jsonString)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Try to decode as wrapped response first
            if let response = try? decoder.decode(TournamentsResponse.self, from: data) {
                print("✅ Decoded as wrapped response")
                return response.tournaments
            }
            
            // Fallback: Try to decode as direct array
            if let tournaments = try? decoder.decode([Tournament].self, from: data) {
                print("✅ Decoded as direct array")
                return tournaments
            }
            
            // If neither worked, throw detailed error
            do {
                _ = try decoder.decode(TournamentsResponse.self, from: data)
            } catch let decodingError as DecodingError {
                print("❌ Decoding Error Details:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch for type \(type): \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found for type \(type): \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                @unknown default:
                    print("Unknown decoding error")
                }
                throw APIError.decodingError(decodingError)
            }
            
            throw APIError.invalidResponse
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func fetchGamesResponse(for tournamentId: Int) async throws -> GamesResponse {
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments/\(tournamentId)/games.json") else {
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            // Debug: Print the raw JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Games JSON Response:")
                print(jsonString)
            }
            
            let decoder = JSONDecoder()
            // Note: NOT using .convertFromSnakeCase - relying on explicit CodingKeys in models
            
            // Try multiple date formats
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try ISO8601 first
                let iso8601Formatter = ISO8601DateFormatter()
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }
                
                // Try common formats
                let formatters = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ]
                
                for format in formatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string: \(dateString)"
                )
            }
            
            // Decode as wrapped response with date grouping
            do {
                let gamesResponse = try decoder.decode(GamesResponse.self, from: data)
                print("✅ Decoded games response with \(gamesResponse.games.count) date groups")
                return gamesResponse
            } catch let decodingError as DecodingError {
                print("❌ Games Decoding Error Details:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch for type \(type): \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found for type \(type): \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                @unknown default:
                    print("Unknown decoding error")
                }
                throw APIError.decodingError(decodingError)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func fetchStandings(for tournamentId: Int) async throws -> [TeamStanding] {
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments/\(tournamentId)/standings.json") else {
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            // Debug: Print the raw JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Standings JSON Response:")
                print(jsonString)
            }
            
            let decoder = JSONDecoder()
            // Note: NOT using .convertFromSnakeCase - relying on explicit CodingKeys in models
            
            // Try to decode as wrapped response first
            if let response = try? decoder.decode(StandingsResponse.self, from: data) {
                print("✅ Decoded standings as wrapped response")
                return response.standings
            }
            
            // Fallback: Try to decode as direct array
            if let standings = try? decoder.decode([TeamStanding].self, from: data) {
                print("✅ Decoded standings as direct array")
                return standings
            }
            
            // If neither worked, throw detailed error
            do {
                _ = try decoder.decode(StandingsResponse.self, from: data)
            } catch let decodingError as DecodingError {
                print("❌ Standings Decoding Error Details:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch for type \(type): \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found for type \(type): \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                @unknown default:
                    print("Unknown decoding error")
                }
                throw APIError.decodingError(decodingError)
            }
            
            throw APIError.invalidResponse
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
    func fetchGames(for tournamentId: Int) async throws -> [Game] {
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments/\(tournamentId)/games.json") else {
            throw APIError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }
            
            // Debug: Print the raw JSON
            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Games JSON Response:")
                print(jsonString)
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            
            // Try multiple date formats
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)
                
                // Try ISO8601 first
                let iso8601Formatter = ISO8601DateFormatter()
                if let date = iso8601Formatter.date(from: dateString) {
                    return date
                }
                
                // Try common formats
                let formatters = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSSZ",
                    "yyyy-MM-dd'T'HH:mm:ssZ",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ]
                
                for format in formatters {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    if let date = formatter.date(from: dateString) {
                        return date
                    }
                }
                
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string: \(dateString)"
                )
            }
            
            // Try to decode as wrapped response first
            if let response = try? decoder.decode(GamesResponse.self, from: data) {
                print("✅ Decoded games as wrapped response")
                return response.allGames
            }
            
            // Fallback: Try to decode as direct array
            if let games = try? decoder.decode([Game].self, from: data) {
                print("✅ Decoded games as direct array")
                return games
            }
            
            // If neither worked, throw detailed error
            do {
                _ = try decoder.decode(GamesResponse.self, from: data)
            } catch let decodingError as DecodingError {
                print("❌ Games Decoding Error Details:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("Key '\(key.stringValue)' not found: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("Type mismatch for type \(type): \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found for type \(type): \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context.debugDescription)")
                    print("Coding path: \(context.codingPath)")
                @unknown default:
                    print("Unknown decoding error")
                }
                throw APIError.decodingError(decodingError)
            }
            
            throw APIError.invalidResponse
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }

    func fetchTopStats(for tournamentId: Int) async throws -> [StatCategory] {
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments/\(tournamentId)/top_stats.json") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ Top Stats: Bad HTTP status")
                throw APIError.invalidResponse
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Top Stats Raw JSON:")
                print(jsonString)
            }

            let decoder = JSONDecoder()

            // Try wrapped: { "top_stats": [...] }
            if let wrapped = try? decoder.decode(TopStatsResponse.self, from: data) {
                print("✅ Decoded top stats — \(wrapped.topStats.count) categories")
                return wrapped.topStats
            }

            // Try direct array: [...]
            if let direct = try? decoder.decode([StatCategory].self, from: data) {
                print("✅ Decoded top stats as direct array — \(direct.count) categories")
                return direct
            }

            // Print detailed decoding error
            do {
                _ = try decoder.decode(TopStatsResponse.self, from: data)
            } catch let decodingError as DecodingError {
                print("❌ Top Stats Decoding Error:")
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("  Key '\(key.stringValue)' not found")
                    print("  Path: \(context.codingPath.map { $0.stringValue })")
                case .typeMismatch(let type, let context):
                    print("  Type mismatch for \(type): \(context.debugDescription)")
                    print("  Path: \(context.codingPath.map { $0.stringValue })")
                case .valueNotFound(let type, let context):
                    print("  Value not found for \(type)")
                    print("  Path: \(context.codingPath.map { $0.stringValue })")
                case .dataCorrupted(let context):
                    print("  Data corrupted: \(context.debugDescription)")
                @unknown default:
                    print("  Unknown decoding error")
                }
                throw APIError.decodingError(decodingError)
            }

            throw APIError.invalidResponse
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Top Stats Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }
}
