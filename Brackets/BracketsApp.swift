//
//  BracketsApp.swift
//  Brackets
//
//  Created by Humberto on 13/02/26.
//

import SwiftUI

@main
struct BracketsApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var availableUpdateVersion: String?

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
                .task {
                    availableUpdateVersion = await AppUpdateChecker.checkForUpdate()
                }
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .active {
                        Task {
                            if let version = await AppUpdateChecker.checkForUpdate() {
                                availableUpdateVersion = version
                            }
                        }
                    }
                }
                .sheet(item: Binding(
                    get: { availableUpdateVersion.map { UpdateVersionItem(version: $0) } },
                    set: { availableUpdateVersion = $0?.version }
                )) { item in
                    UpdateAvailableSheet(newVersion: item.version) {
                        availableUpdateVersion = nil
                    }
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
                }
        }
    }
}

private struct UpdateVersionItem: Identifiable {
    let version: String
    var id: String { version }
}
