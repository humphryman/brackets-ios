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
    
    var filteredTournaments: [Tournament] {
        tournaments.filter { $0.gender == selectedGender }
    }
    
    func loadTournaments() async {
        isLoading = true
        errorMessage = nil
        
        do {
            tournaments = try await APIService.shared.fetchTournaments()
        } catch let error as APIError {
            errorMessage = error.localizedDescription
        } catch {
            errorMessage = "An unexpected error occurred"
        }
        
        isLoading = false
    }
}
