//
//  TournamentsViewModel.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import Foundation

@MainActor
@Observable
class TournamentsViewModel {
    var tournaments: [Tournament] = []
    var selectedGender: Gender = .male
    var isLoading = false
    var errorMessage: String?
    
    var availableGenders: [Gender] {
        Gender.allCases.filter { gender in tournaments.contains { $0.gender == gender } }
    }

    var showsGenderTabs: Bool {
        availableGenders.count >= 2
    }

    var filteredTournaments: [Tournament] {
        guard showsGenderTabs else { return tournaments }
        return tournaments.filter { $0.gender == nil || $0.gender == selectedGender }
    }
    
    func loadTournaments() async {
        // Only show the spinner on a cold load. A refresh that happens while the
        // list is already on screen must not tear the ScrollView down, or the
        // user's scroll position is lost on every back-navigation.
        let isColdLoad = tournaments.isEmpty
        isLoading = isColdLoad
        errorMessage = nil

        do {
            tournaments = try await APIService.shared.fetchTournaments()
        } catch APIError.invalidResponse {
            // Server returns non-200 for customers with no tournaments
            tournaments = []
        } catch let error as APIError {
            // A failed refresh keeps the list the user is looking at
            if isColdLoad { errorMessage = error.localizedDescription }
        } catch {
            if isColdLoad { errorMessage = "An unexpected error occurred" }
        }

        isLoading = false
    }
}
