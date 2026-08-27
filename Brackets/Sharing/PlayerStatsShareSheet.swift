//
//  PlayerStatsShareSheet.swift
//  Brackets
//

import SwiftUI
import UIKit

/// Share overlay for one athlete's game stat line.
///
/// Mirrors `ShareGameSheet` without the paging: there is a single card design, so the
/// preview sits centred above the destinations.
struct PlayerStatsShareSheet: View {
    let player: PlayerGameStat
    let teamName: String
    let detail: GameDetailResponse
    var tournamentName: String?

    @Environment(\.dismiss) private var dismiss

    @State private var model: PlayerStatsShareModel?

    /// Matches the game sheet's carousel width so both share sheets read at one scale.
    private static let cardWidth: CGFloat = 260

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                if let model {
                    Spacer(minLength: AppTheme.Layout.sectionSpacing)

                    ShareCardThumbnail(width: Self.cardWidth) {
                        PlayerPortraitShareCard(model: model)
                    }

                    Spacer(minLength: AppTheme.Layout.sectionSpacing)

                    ShareExportSection(render: renderCurrent)
                } else {
                    Spacer()
                    ProgressView()
                        .tint(AppTheme.Colors.accent)
                        .scaleEffect(1.2)
                    Spacer()
                }
            }
        }
        .task {
            model = await PlayerStatsShareModel.make(
                player: player,
                teamName: teamName,
                detail: detail,
                tournamentName: tournamentName
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        AppTheme.ScreenHeader(title: "Compartir", leadingIcon: "xmark", onLeading: { dismiss() })
            .padding(.horizontal, AppTheme.Layout.screenPadding)
            .padding(.top, AppTheme.Layout.large)
            .padding(.bottom, AppTheme.Layout.itemSpacing)
    }

    // MARK: - Rendering

    private func renderCurrent() -> UIImage? {
        guard let model else { return nil }
        return ShareImageRenderer.render(PlayerPortraitShareCard(model: model))
    }
}
