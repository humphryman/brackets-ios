//
//  PlayerStatsShareCardPreviews.swift
//  Brackets
//
//  Preview-only fixtures for the athlete card. The stat-count cases are the
//  load-bearing ones: 8 stats is the height worst case, and the long-name case is what
//  the shared name scale ladder exists for.
//

#if DEBUG
import SwiftUI
import UIKit

extension PlayerStatsShareModel {

    /// Stand-in artwork so previews exercise the image code paths without network.
    private static func sampleImage(_ symbol: String, tint: UIColor) -> UIImage? {
        let config = UIImage.SymbolConfiguration(pointSize: 160, weight: .bold)
        return UIImage(systemName: symbol, withConfiguration: config)?
            .withTintColor(tint, renderingMode: .alwaysOriginal)
    }

    private static let sampleStats: [StatCell] = [
        StatCell(id: "points", value: "12", label: "Puntos"),
        StatCell(id: "2pm", value: "1", label: "2 Puntos"),
        StatCell(id: "3pm", value: "3", label: "3 Puntos"),
        StatCell(id: "ftm", value: "1", label: "Tiros Libres"),
        StatCell(id: "reb", value: "7", label: "Rebotes"),
        StatCell(id: "ast", value: "4", label: "Asistencias"),
        StatCell(id: "stl", value: "2", label: "Robos"),
        StatCell(id: "blk", value: "1", label: "Bloqueos")
    ]

    /// Finished game, photo and both logos present.
    static func preview(statCount: Int) -> PlayerStatsShareModel {
        var model = PlayerStatsShareModel()
        model.firstName = "Nicolás"
        model.lastName = "Reyes Peña"
        model.teamName = "WW LEONES 10-11"
        model.photo = sampleImage("person.crop.square.fill", tint: .systemTeal)
        model.stats = Array(sampleStats.prefix(statCount))
        model.teamAName = "CETIS 58"
        model.teamBName = "WW LEONES 10-11"
        model.teamALogo = sampleImage("shield.fill", tint: .systemIndigo)
        model.teamBLogo = sampleImage("flame.fill", tint: .systemOrange)
        model.teamAScore = 52
        model.teamBScore = 58
        model.tournamentName = "Varonil 2008-2009"
        model.date = Date()
        model.venueName = "Cintermex C11"
        return model
    }

    /// Two-word given name and a two-word surname — the case that autoscaling used to
    /// shrink the given name below the surname, inverting the card's hierarchy.
    static var previewLongName: PlayerStatsShareModel {
        var model = preview(statCount: 5)
        model.firstName = "Aquiles Anhuar"
        model.lastName = "Rodriguez Montoya"
        model.teamName = "SAN LUIS POTOSI A"
        return model
    }

    /// No photo and no logos — exercises every initials fallback at once.
    static var previewNoImages: PlayerStatsShareModel {
        var model = preview(statCount: 6)
        model.firstName = "Maximiliano"
        model.lastName = "Hernández Villalobos"
        model.photo = nil
        model.teamALogo = nil
        model.teamBLogo = nil
        model.teamAName = "Deportivo Guadalupe Victoria"
        model.teamBName = "Club Atlético Universitario"
        return model
    }
}

#Preview("6 stats") {
    PlayerPortraitShareCard(model: .preview(statCount: 6))
}

/// Worst case for height: four rows of stats above the score strip.
#Preview("8 stats") {
    PlayerPortraitShareCard(model: .preview(statCount: 8))
}

#Preview("long name") {
    PlayerPortraitShareCard(model: .previewLongName)
}

#Preview("no photo or logos") {
    PlayerPortraitShareCard(model: .previewNoImages)
}

// MARK: - Rasterized

/// The load-bearing one: the actual rasterized bitmap, which is where a regression to
/// blank, clipped or off-canvas imagery would surface.
#Preview("Rendered output") {
    let image = ShareImageRenderer.render(PlayerPortraitShareCard(model: .preview(statCount: 6)))

    return Group {
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            Text("Render failed")
        }
    }
}
#endif
