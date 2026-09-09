import SwiftUI

enum FinalCardSize {
    case prominent
    case compact

    var dateSize: CGFloat { self == .prominent ? 15 : 12 }
    var nameSize: CGFloat { self == .prominent ? 15 : 13 }
    var vsSize: CGFloat { self == .prominent ? 18 : 15 }
    var venueSize: CGFloat { self == .prominent ? 15 : 13 }
    var verticalPadding: CGFloat { self == .prominent ? 26 : 16 }
}

/// One Final (or Tercer Lugar) card: animated background + crest row + result
/// region + optional countdown + venue footer. Tappable when a real game backs it.
struct FinalMatchCard: View {
    let matchup: BracketMatchup
    let stageLabel: String
    let size: FinalCardSize
    let colorA: Color
    let colorB: Color
    let tournament: Tournament
    /// Tightens the vertical rhythm so both cards fit on screen when the Final
    /// and Tercer Lugar cards are shown together.
    var dense: Bool = false

    @Environment(\.openURL) private var openURL

    private var isLive: Bool { matchup.game?.isLive ?? false }
    private var isFinished: Bool { matchup.game?.isFinished ?? false }
    private var decided: Bool { matchup.homeIsWinner || matchup.awayIsWinner }

    // Crest and time dominate card height, so `dense` (two-card layout) shrinks
    // them further on top of the base per-size values.
    private var crestDiameter: CGFloat {
        size == .prominent ? (dense ? 74 : 88) : (dense ? 60 : 72)
    }
    private var timeSize: CGFloat {
        size == .prominent ? (dense ? 46 : 58) : (dense ? 28 : 34)
    }

    var body: some View {
        let content = card
        if let game = matchup.game {
            NavigationLink {
                destination(for: game)
            } label: { content }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    @ViewBuilder
    private func destination(for game: Game) -> some View {
        if game.isLive {
            LiveGameDetailView(game: game, tournamentId: tournament.id, tournamentName: tournament.name)
        } else if game.isFinished {
            GameResultView(game: game, tournamentId: tournament.id, tournamentName: tournament.name, gender: tournament.gender)
        } else {
            UpcomingGameView(game: game, tournamentId: tournament.id, gender: tournament.gender)
        }
    }

    private var card: some View {
        let prominent = size == .prominent
        // Gaps: pill→crest, crest→date, time→divider. `dense` tightens all three
        // (and the card padding) so Final + Tercer Lugar fit on one screen.
        let topGap: CGFloat = dense ? (prominent ? 26 : 16) : (prominent ? 50 : 26)
        let midGap: CGFloat = dense ? (prominent ? 22 : 14) : (prominent ? 46 : 22)
        let belowGap: CGFloat = dense ? (prominent ? 26 : 16) : (prominent ? 58 : 30)
        let vPad: CGFloat = dense ? (prominent ? 18 : 14) : size.verticalPadding
        return VStack(spacing: 0) {
            stagePill
            Spacer().frame(height: topGap)
            crestRow
            Spacer().frame(height: midGap)
            resultRegion
            Spacer().frame(height: belowGap)
            divider
            Spacer().frame(height: dense ? 12 : 14)
            venueFooter(matchup.venue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, vPad)
        .padding(.horizontal, 18)
        .background(FinalCardBackground(colorA: colorA, colorB: colorB))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .top) {
            if isLive { BracketLiveBadge().offset(y: -9) }
        }
    }

    private var stagePill: some View {
        Badge(stageLabel.uppercased(), style: .gray)
    }

    private var crestRow: some View {
        HStack(alignment: .top, spacing: 12) {
            teamColumn(team: matchup.homeTeam, placeholder: matchup.homePlaceholder, isWinner: matchup.homeIsWinner)
            VStack {
                Text("VS")
                    .font(AppTheme.Typography.condensed(.bold, size: size.vsSize))
                    .foregroundStyle(.white)
                    .frame(height: crestDiameter)
            }
            teamColumn(team: matchup.awayTeam, placeholder: matchup.awayPlaceholder, isWinner: matchup.awayIsWinner)
        }
    }

    private func teamColumn(team: Team?, placeholder: String?, isWinner: Bool) -> some View {
        let name = team?.name ?? placeholder ?? "TBD"
        return VStack(spacing: 10) {
            crest(team: team, name: name)
            Text(name.uppercased())
                .font(AppTheme.Typography.condensed(isWinner ? .bold : .semibold, size: size.nameSize))
                .foregroundStyle(isWinner || !decided ? .white : Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func crest(team: Team?, name: String) -> some View {
        let d = crestDiameter
        if let urlString = team?.fullImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                default: initialChip(name: name, diameter: d)
                }
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .overlay(Circle().stroke(AppTheme.Colors.gray700, lineWidth: 1))
        } else {
            initialChip(name: name, diameter: d)
        }
    }

    private func initialChip(name: String, diameter: CGFloat) -> some View {
        Circle()
            .fill(AppTheme.Colors.gray700)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(String(name.first.map(String.init) ?? "?").uppercased())
                    .font(AppTheme.Typography.condensed(.bold, size: diameter * 0.46))
                    .foregroundStyle(.white)
            )
            .overlay(Circle().stroke(AppTheme.Colors.gray700, lineWidth: 1))
    }

    @ViewBuilder
    private var resultRegion: some View {
        if isLive || isFinished {
            HStack(spacing: 18) {
                scoreText(matchup.homeScore, isWinner: matchup.homeIsWinner)
                Text("-").font(AppTheme.Typography.condensed(.bold, size: timeSize)).foregroundStyle(.white.opacity(0.5))
                scoreText(matchup.awayScore, isWinner: matchup.awayIsWinner)
            }
        } else {
            VStack(spacing: 4) {
                if let time = matchup.scheduledTime {
                    Text(Self.dateFormatter.string(from: time).uppercased())
                        .font(AppTheme.Typography.condensed(.semibold, size: size.dateSize))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(Self.timeFormatter.string(from: time))
                        .font(AppTheme.Typography.condensed(.semibold, size: timeSize))
                        .foregroundStyle(.white)
                } else {
                    Text("SIN AGENDAR")
                        .font(AppTheme.Typography.condensed(.bold, size: size == .prominent ? 34 : 22))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .padding(.top, size == .prominent ? 20 : 10)
                }
            }
        }
    }

    private func scoreText(_ score: Int?, isWinner: Bool) -> some View {
        let color: Color = isWinner
            ? AppTheme.Colors.accent
            : (decided ? Color(white: 0.5) : .white)
        return Text(score.map(String.init) ?? "-")
            .font(AppTheme.Typography.condensed(.bold, size: timeSize))
            .foregroundStyle(color)
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.horizontal, 8)
    }

    @ViewBuilder
    private func venueFooter(_ venue: Venue?) -> some View {
        if let venue {
            let row = HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 13))
                Text(venue.name).font(.system(size: size.venueSize, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.9))

            if let mapsURL = venue.googleMapsURL {
                Button { openURL(mapsURL) } label: { row }.buttonStyle(.plain)
            } else {
                row
            }
        } else {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse").font(.system(size: 13))
                Text("Ubicación por definir").font(.system(size: size.venueSize, weight: .medium))
            }
            .foregroundStyle(.white.opacity(0.55))
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "d MMMM, yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.timeZone = AppConfig.DateTime.apiTimeZone
        f.dateFormat = "h:mm a"
        f.amSymbol = "AM"; f.pmSymbol = "PM"
        return f
    }()
}
