//
//  BracketsApp.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import SwiftUI

@main
struct BracketsApp: App {
    init() {
        // Set default navigation bar background to black
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some Scene {
        WindowGroup {
            LeagueSelectionView()
                .preferredColorScheme(.dark)
        }
    }
}
