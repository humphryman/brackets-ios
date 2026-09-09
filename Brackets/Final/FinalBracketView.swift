import SwiftUI

/// True when a matchup carries any information — a real game, or a placeholder
/// that contributed a team name, a time, or a venue.
private func finalMatchupHasInfo(_ m: BracketMatchup) -> Bool {
    m.hasGame || m.homePlaceholder != nil || m.awayPlaceholder != nil || m.scheduledTime != nil || m.venue != nil
}

/// Full-screen layout for the `final` bracket type. Shows the Final card always
/// (TBD when it has no info) and the Tercer Lugar card only when it has info.
struct FinalBracketView: View {
    let finalMatchup: BracketMatchup
    let thirdMatchup: BracketMatchup
    let tournament: Tournament

    @State private var finalA: HSLColor?
    @State private var finalB: HSLColor?
    @State private var thirdA: HSLColor?
    @State private var thirdB: HSLColor?

    private var showsThird: Bool { finalMatchupHasInfo(thirdMatchup) }

    var body: some View {
        Group {
            if showsThird {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        finalCard(size: .compact)
                        thirdCard(size: .compact)
                    }
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                    .padding(.bottom, 24)
                }
            } else {
                finalCard(size: .prominent)
                    .padding(.horizontal, AppTheme.Layout.screenPadding)
                    .padding(.bottom, 24)
            }
        }
        .task { await resolveColors() }
    }

    private func finalCard(size: FinalCardSize) -> some View {
        let pair = resolveFinalPair(a: finalA, b: finalB)
        return FinalMatchCard(
            matchup: finalMatchup, stageLabel: "FINAL", size: size,
            colorA: pair.0, colorB: pair.1, tournament: tournament
        )
        .animation(.easeInOut(duration: 0.4), value: finalA)
        .animation(.easeInOut(duration: 0.4), value: finalB)
    }

    private func thirdCard(size: FinalCardSize) -> some View {
        let pair = resolveFinalPair(a: thirdA, b: thirdB)
        return FinalMatchCard(
            matchup: thirdMatchup, stageLabel: "TERCER LUGAR", size: size,
            colorA: pair.0, colorB: pair.1, tournament: tournament
        )
        .animation(.easeInOut(duration: 0.4), value: thirdA)
        .animation(.easeInOut(duration: 0.4), value: thirdB)
    }

    private func resolveColors() async {
        let store = TeamColorStore.shared
        async let fa = store.color(forTeamId: finalMatchup.homeTeam?.id, logoURL: finalMatchup.homeTeam?.fullImageURL)
        async let fb = store.color(forTeamId: finalMatchup.awayTeam?.id, logoURL: finalMatchup.awayTeam?.fullImageURL)
        finalA = await fa
        finalB = await fb
        if showsThird {
            async let ta = store.color(forTeamId: thirdMatchup.homeTeam?.id, logoURL: thirdMatchup.homeTeam?.fullImageURL)
            async let tb = store.color(forTeamId: thirdMatchup.awayTeam?.id, logoURL: thirdMatchup.awayTeam?.fullImageURL)
            thirdA = await ta
            thirdB = await tb
        }
    }
}
