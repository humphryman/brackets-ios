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
struct TournamentsResponse: Codable, Sendable {
    let tournaments: [Tournament]
}

// Response wrapper for standings
struct StandingsResponse: Codable, Sendable {
    let standings: [TeamStanding]?
    let groupStandings: [GroupStanding]?
    let podium: Podium?
    let classification: Classification?

    enum CodingKeys: String, CodingKey {
        case standings
        case groupStandings = "group_standings"
        case podium
        case classification
    }
}

// MARK: - Classification (playoff seeding table)

struct ClassificationBracket: Codable, Sendable, Hashable, Identifiable {
    let position: Int
    let name: String
    let type: String?
    let typeLabel: String?
    let capacity: Int
    let filled: Int
    let startSeed: Int?

    var id: String { name }

    enum CodingKeys: String, CodingKey {
        case position, name, type, capacity, filled
        case typeLabel = "type_label"
        case startSeed = "start_seed"
    }
}

struct ClassificationTeam: Codable, Sendable, Hashable, Identifiable {
    let teamSeasonId: Int
    let name: String
    let teamLogo: String?
    let group: String?
    let place: Int?
    let avg: Double?
    let classified: Bool
    let bracket: String?
    let seed: Int?

    var id: Int { teamSeasonId }

    enum CodingKeys: String, CodingKey {
        case name, group, place, avg, classified, bracket, seed
        case teamSeasonId = "team_season_id"
        case teamLogo = "team_logo"
    }
}

struct Classification: Codable, Sendable, Hashable {
    let brackets: [ClassificationBracket]
    let teams: [ClassificationTeam]
}

// MARK: - Podium

struct PodiumEntry: Codable, Sendable, Hashable {
    let place: Int
    let teamId: Int?
    let teamSeasonId: Int?
    let teamName: String
    let teamLogo: String?

    enum CodingKeys: String, CodingKey {
        case place
        case teamId = "team_id"
        case teamSeasonId = "team_season_id"
        case teamName = "team_name"
        case teamLogo = "team_logo"
    }

    var fullImageURL: String? {
        guard let logo = teamLogo else { return nil }
        if logo.lowercased().hasPrefix("http://") || logo.lowercased().hasPrefix("https://") {
            return logo
        }
        let path = logo.hasPrefix("/") ? String(logo.dropFirst()) : logo
        return "\(APIConfig.baseURL)/\(path)"
    }
}

struct Podium: Codable, Sendable, Hashable {
    let tournamentName: String
    let first: PodiumEntry
    let second: PodiumEntry?
    let third: PodiumEntry?

    enum CodingKeys: String, CodingKey {
        case tournamentName = "tournament_name"
        case first
        case second
        case third
    }
}

struct StandingsBundle: Sendable {
    let result: StandingsResult
    let podium: Podium?
    let classification: Classification?
}

// Group Standing Model
struct GroupStanding: Identifiable, Codable, Sendable {
    let name: String
    let standings: [TeamStanding]

    var id: String { name }
}

// Result type for standings endpoint
enum StandingsResult: Sendable {
    case flat([TeamStanding])
    case groups([GroupStanding])

    var isEmpty: Bool {
        switch self {
        case .flat(let standings): return standings.isEmpty
        case .groups(let groups): return groups.isEmpty
        }
    }
}

// MARK: - Tiebreaker Models

struct Tiebreaker: Codable, Sendable, Equatable, Identifiable {
    enum Reason: String, Codable, Sendable {
        case fibaScore = "fiba_score"
        case h2h
        case miniTable = "mini_table"
    }

    let groupIndex: Int?
    let bucketId: Int
    let bucketSize: Int
    let reason: Reason
    let fibaBreakdown: [FibaEntry]?
    let h2hGames: [H2HGame]?
    let miniTable: [MiniTableEntry]?

    var id: String { "\(groupIndex ?? 0)-\(bucketId)" }

    enum CodingKeys: String, CodingKey {
        case groupIndex = "group_index"
        case bucketId = "bucket_id"
        case bucketSize = "bucket_size"
        case reason
        case fibaBreakdown = "fiba_breakdown"
        case h2hGames = "h2h_games"
        case miniTable = "mini_table"
    }
}

struct FibaEntry: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
    let fibaScore: Int

    enum CodingKeys: String, CodingKey {
        case id, name
        case fibaScore = "fiba_score"
    }
}

struct H2HGame: Codable, Sendable, Equatable, Identifiable {
    let teamA: H2HSide
    let teamB: H2HSide

    var id: String { "\(teamA.id)-\(teamB.id)-\(teamA.score)-\(teamB.score)" }

    enum CodingKeys: String, CodingKey {
        case teamA = "team_a"
        case teamB = "team_b"
    }
}

struct H2HSide: Codable, Sendable, Equatable {
    let id: Int
    let name: String
    let score: Int
    let winner: Bool
}

struct MiniTableEntry: Codable, Sendable, Equatable, Identifiable {
    let id: Int
    let name: String
    let favor: Int
    let against: Int

    var diff: Int { favor - against }
}

// Team Standing Model
struct TeamStanding: Identifiable, Codable, Sendable {
    let id: Int
    let teamName: String
    let total: Int
    let wins: Int
    let losses: Int
    let pointsFor: Int
    let pointsAgainst: Int
    let tie: Int
    let diff: Int?
    let avg: Double?
    let tieBreaker: String?
    let tiebreaker: Tiebreaker?
    let teamLogo: String?

    // Point differential — prefer API value, fall back to computed
    var pointDifferential: Int {
        diff ?? (pointsFor - pointsAgainst)
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
        case diff
        case avg
        case tieBreaker = "tie_breaker"
        case tiebreaker
        case teamLogo = "team_logo"
    }
}

final class APIService: Sendable {
    static let shared = APIService()

    private init() {}

    func fetchCustomers() async throws -> [Customer] {
        guard let url = URL(string: AppConfig.API.customersAPIURL) else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(AppConfig.API.customersAPIToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            let decoder = JSONDecoder()
            do {
                let customers = try decoder.decode([Customer].self, from: data)
                print("✅ Decoded \(customers.count) customers")
                return customers
            } catch let decodingError {
                print("❌ Customers Decoding Error: \(decodingError)")
                throw APIError.decodingError(decodingError)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
    
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
                
                // Strip timezone offset — always interpret as API timezone
                let cleanedDateString = dateString
                    .replacingOccurrences(of: #"[+-]\d{2}:\d{2}$"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"Z$"#, with: "", options: .regularExpression)

                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSS",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ]

                for format in formats {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = AppConfig.DateTime.apiTimeZone
                    if let date = formatter.date(from: cleanedDateString) {
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
    
    func fetchStandings(for tournamentId: Int) async throws -> StandingsBundle {
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

            // Try to decode as wrapped response first
            if let response = try? decoder.decode(StandingsResponse.self, from: data) {
                if let groups = response.groupStandings, !groups.isEmpty {
                    // Single group named "DEFAULT" means no real groups — treat as flat
                    if groups.count == 1, groups[0].name.uppercased() == "DEFAULT" {
                        print("✅ Decoded standings as flat (single DEFAULT group)")
                        return StandingsBundle(result: .flat(groups[0].standings), podium: response.podium, classification: response.classification)
                    }
                    print("✅ Decoded standings as group standings")
                    return StandingsBundle(result: .groups(groups), podium: response.podium, classification: response.classification)
                }
                if let standings = response.standings, !standings.isEmpty {
                    print("✅ Decoded standings as wrapped response")
                    return StandingsBundle(result: .flat(standings), podium: response.podium, classification: response.classification)
                }
            }

            // Fallback: Try to decode as direct array
            if let standings = try? decoder.decode([TeamStanding].self, from: data) {
                print("✅ Decoded standings as direct array")
                return StandingsBundle(result: .flat(standings), podium: nil, classification: nil)
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
                
                // Strip timezone offset — always interpret as API timezone
                let cleanedDateString = dateString
                    .replacingOccurrences(of: #"[+-]\d{2}:\d{2}$"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"Z$"#, with: "", options: .regularExpression)

                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSS",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ]

                for format in formats {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = AppConfig.DateTime.apiTimeZone
                    if let date = formatter.date(from: cleanedDateString) {
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

    func fetchGameDetail(tournamentId: Int, gameId: Int) async throws -> GameDetailResponse {
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments/\(tournamentId)/games/\(gameId).json") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Game Detail JSON Response:")
                print(jsonString)
            }

            let decoder = JSONDecoder()

            // Custom date decoding (same as fetchGamesResponse)
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Strip timezone offset — always interpret as API timezone
                let cleanedDateString = dateString
                    .replacingOccurrences(of: #"[+-]\d{2}:\d{2}$"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"Z$"#, with: "", options: .regularExpression)

                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSS",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ]

                for format in formats {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = AppConfig.DateTime.apiTimeZone
                    if let date = formatter.date(from: cleanedDateString) {
                        return date
                    }
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string: \(dateString)"
                )
            }

            do {
                let gameDetail = try decoder.decode(GameDetailResponse.self, from: data)
                print("✅ Decoded game detail for game \(gameId)")
                return gameDetail
            } catch let decodingError as DecodingError {
                print("❌ Game Detail Decoding Error:")
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
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Game Detail Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }

    func fetchTeamSeason(teamSeasonId: Int) async throws -> TeamSeasonDetail {
        guard let url = URL(string: "\(APIConfig.apiURL)/team_seasons/\(teamSeasonId).json") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Team Season JSON Response:")
                print(jsonString)
            }

            let decoder = JSONDecoder()

            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let dateString = try container.decode(String.self)

                // Strip timezone offset — always interpret as API timezone
                let cleanedDateString = dateString
                    .replacingOccurrences(of: #"[+-]\d{2}:\d{2}$"#, with: "", options: .regularExpression)
                    .replacingOccurrences(of: #"Z$"#, with: "", options: .regularExpression)

                let formats = [
                    "yyyy-MM-dd'T'HH:mm:ss.SSS",
                    "yyyy-MM-dd'T'HH:mm:ss",
                    "yyyy-MM-dd HH:mm:ss",
                    "yyyy-MM-dd"
                ]

                for format in formats {
                    let formatter = DateFormatter()
                    formatter.dateFormat = format
                    formatter.locale = Locale(identifier: "en_US_POSIX")
                    formatter.timeZone = AppConfig.DateTime.apiTimeZone
                    if let date = formatter.date(from: cleanedDateString) {
                        return date
                    }
                }

                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Cannot decode date string: \(dateString)"
                )
            }

            do {
                let teamSeasonResponse = try decoder.decode(TeamSeasonResponse.self, from: data)
                print("✅ Decoded team season \(teamSeasonId)")
                return teamSeasonResponse.teamSeason
            } catch let decodingError as DecodingError {
                print("❌ Team Season Decoding Error:")
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
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Team Season Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }

    func fetchPlayerSeason(playerSeasonId: Int) async throws -> PlayerSeasonDetailResponse {
        guard let url = URL(string: "\(APIConfig.apiURL)/player_seasons/\(playerSeasonId).json") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                throw APIError.invalidResponse
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("📦 Player Season JSON Response:")
                print(jsonString)
            }

            let decoder = JSONDecoder()

            do {
                let detail = try decoder.decode(PlayerSeasonDetailResponse.self, from: data)
                print("✅ Decoded player season \(playerSeasonId)")
                return detail
            } catch let decodingError as DecodingError {
                print("❌ Player Season Decoding Error:")
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
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Player Season Network Error: \(error)")
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

    func fetchTopStatDetail(for tournamentId: Int, stat: String) async throws -> TopStatDetail {
        let encodedStat = stat.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stat
        guard let url = URL(string: "\(APIConfig.apiURL)/tournaments/\(tournamentId)/top_stat.json?stat=\(encodedStat)") else {
            throw APIError.invalidURL
        }

        do {
            let (data, response) = try await URLSession.shared.data(from: url)

            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                print("❌ Top Stat Detail: Bad HTTP status")
                throw APIError.invalidResponse
            }

            do {
                let detail = try JSONDecoder().decode(TopStatDetail.self, from: data)
                print("✅ Decoded top stat detail — \(detail.players.count) players")
                return detail
            } catch let decodingError {
                print("❌ Top Stat Detail Decoding Error: \(decodingError)")
                throw APIError.decodingError(decodingError)
            }
        } catch let error as APIError {
            throw error
        } catch {
            print("❌ Top Stat Detail Network Error: \(error)")
            throw APIError.networkError(error)
        }
    }
}
