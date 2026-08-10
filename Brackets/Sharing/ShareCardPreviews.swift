//
//  ShareCardPreviews.swift
//  Brackets
//
//  Preview-only fixtures. The `Rendered output` preview is the load-bearing one:
//  it exercises `ShareImageRenderer` and shows the actual rasterized bitmap, which
//  is where a regression to blank/missing imagery would surface.
//

#if DEBUG
import SwiftUI

extension ShareCardModel {

    /// Stand-in artwork so previews exercise the image code paths without network.
    private static func sampleLogo(_ symbol: String, tint: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 160, weight: .bold)
        return UIImage(systemName: symbol, withConfiguration: config)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
    }

    private static var samplePeriods: [String: QuarterScoreValue]? {
        let json = Data(#"{"q1": 22, "q2": 18, "q3": 25, "q4": 20}"#.utf8)
        return try? JSONDecoder().decode([String: QuarterScoreValue].self, from: json)
    }

    private static var samplePeriodsB: [String: QuarterScoreValue]? {
        let json = Data(#"{"q1": 19, "q2": 24, "q3": 17, "q4": 21}"#.utf8)
        return try? JSONDecoder().decode([String: QuarterScoreValue].self, from: json)
    }

    /// Finished game, both logos present, period breakdown available.
    static var previewFinished: ShareCardModel {
        var model = ShareCardModel()
        model.tournamentName = "Liga Municipal de Tijuana"
        model.stage = "Semifinal"
        model.date = Date()
        model.venueName = "Gimnasio Municipal · Cancha 2"
        model.teamAName = "Halcones"
        model.teamBName = "Venados"
        model.gender = .male
        model.teamALogo = sampleLogo("shield.fill", tint: .systemIndigo)
        model.teamBLogo = sampleLogo("flame.fill", tint: .systemOrange)
        model.teamAScore = 85
        model.teamBScore = 81
        model.teamAPeriodScores = samplePeriods
        model.teamBPeriodScores = samplePeriodsB
        model.hasPeriodScores = true
        return model
    }

    /// Female tournament — exercises the right-edge gender label.
    static var previewFemenil: ShareCardModel {
        var model = previewFinished
        model.gender = .female
        model.stage = "Final"
        return model
    }

    /// No logos at all and names long enough to force the scale-down path.
    static var previewNoLogos: ShareCardModel {
        var model = ShareCardModel()
        model.tournamentName = "Torneo de Clausura Femenil 2026"
        model.stage = "Cuartos de final"
        model.date = Date()
        model.venueName = "Polideportivo Zona Río"
        model.teamAName = "Deportivo Guadalupe Victoria"
        model.teamBName = "Club Atlético Universitario"
        model.teamAScore = 104
        model.teamBScore = 98
        return model
    }

    /// Tie — neither side should take the accent treatment.
    static var previewTie: ShareCardModel {
        var model = previewFinished
        model.teamAScore = 77
        model.teamBScore = 77
        model.hasPeriodScores = false
        return model
    }

    /// Unplayed game: scores stay `nil` so cards show VS + kickoff, never "0 - 0".
    static var previewUpcoming: ShareCardModel {
        var model = previewFinished
        model.teamAScore = nil
        model.teamBScore = nil
        model.hasPeriodScores = false
        model.stage = "Final"
        return model
    }
}

// MARK: - Card previews

#Preview("Scoreboard · finished") {
    ShareCardContainer(style: .scoreboard, model: .previewFinished)
}

#Preview("Scoreboard · no logos, long names") {
    ShareCardContainer(style: .scoreboard, model: .previewNoLogos)
}

#Preview("Scoreboard · femenil") {
    ShareCardContainer(style: .scoreboard, model: .previewFemenil)
}

#Preview("Scoreboard · tie") {
    ShareCardContainer(style: .scoreboard, model: .previewTie)
}

#Preview("Scoreboard · upcoming") {
    ShareCardContainer(style: .scoreboard, model: .previewUpcoming)
}

#Preview("Spotlight · finished") {
    ShareCardContainer(style: .spotlight, model: .previewFinished)
}

#Preview("Spotlight · femenil") {
    ShareCardContainer(style: .spotlight, model: .previewFemenil)
}

#Preview("Spotlight · no logos") {
    ShareCardContainer(style: .spotlight, model: .previewNoLogos)
}

#Preview("Spotlight · upcoming") {
    ShareCardContainer(style: .spotlight, model: .previewUpcoming)
}

// MARK: - Rasterization check

/// Renders both designs through `ShareImageRenderer` and displays the resulting
/// bitmaps with their pixel dimensions. Both should read 1080 × 1920 and show the
/// stand-in logos — blank logos here mean the pre-fetch contract was broken somewhere.
private struct RenderedOutputPreview: View {
    let model: ShareCardModel

    var body: some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 16) {
                ForEach(ShareCardStyle.allCases) { style in
                    VStack(spacing: 8) {
                        if let image = ShareImageRenderer.render(style, model: model) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 480)

                            Text("\(Int(image.size.width * image.scale)) × \(Int(image.size.height * image.scale)) px")
                                .font(.caption.monospaced())
                                .foregroundStyle(.white)
                        } else {
                            Text("render failed")
                                .foregroundStyle(.red)
                        }

                        Text(style.displayName)
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .padding()
        }
        .background(Color.black)
    }
}

#Preview("Rendered output · 1080×1920") {
    RenderedOutputPreview(model: .previewFinished)
}

// MARK: - Sheet components

/// The sheet's own layout. Worth previewing here because `ImageRenderer` cannot
/// rasterize a `ScrollView`, so the carousel is invisible in any snapshot-based check —
/// the Xcode canvas is the only place the paging and neighbour-peek can be seen.
private struct SheetComponentsPreview: View {
    @State private var selection: ShareCardStyle? = .scoreboard

    var body: some View {
        ZStack {
            AppTheme.Colors.background.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: AppTheme.Layout.sectionSpacing)
                ShareCardCarousel(model: .previewFinished, selection: $selection)
                Spacer(minLength: AppTheme.Layout.sectionSpacing)
                ShareDestinationRow(onInstagram: {}, onSave: {}, onMore: {})
            }
        }
    }
}

#Preview("Sheet · carousel + destinations") {
    SheetComponentsPreview()
}
#endif
