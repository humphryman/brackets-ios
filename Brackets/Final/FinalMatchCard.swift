import SwiftUI

enum FinalCardSize {
    case prominent
    case compact

    var crestDiameter: CGFloat { self == .prominent ? 132 : 84 }
    var timeSize: CGFloat { self == .prominent ? 60 : 34 }
    var dateSize: CGFloat { self == .prominent ? 15 : 12 }
    var nameSize: CGFloat { self == .prominent ? 20 : 15 }
    var showsCountdown: Bool { self == .prominent }
    var verticalPadding: CGFloat { self == .prominent ? 28 : 18 }
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

    @Environment(\.openURL) private var openURL

    private var isLive: Bool { matchup.game?.isLive ?? false }
    private var isFinished: Bool { matchup.game?.isFinished ?? false }
    private var decided: Bool { matchup.homeIsWinner || matchup.awayIsWinner }

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
        VStack(spacing: size == .prominent ? 22 : 12) {
            stagePill
            crestRow
            resultRegion
            if size.showsCountdown, let text = FinalCountdown.label(until: matchup.scheduledTime, isLiveOrFinished: isLive || isFinished) {
                countdownPill(text)
            }
            Spacer(minLength: 0)
            if let venue = matchup.venue {
                divider
                venueFooter(venue)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, size.verticalPadding)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: size == .prominent ? .infinity : nil)
        .background(FinalCardBackground(colorA: colorA, colorB: colorB))
        .overlay(alignment: .top) {
            if isLive { BracketLiveBadge().offset(y: -9) }
        }
    }

    private var stagePill: some View {
        Text(stageLabel.uppercased())
            .font(AppTheme.Typography.condensed(.semibold, size: 14))
            .tracking(1)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }

    private var crestRow: some View {
        HStack(alignment: .top, spacing: 12) {
            teamColumn(team: matchup.homeTeam, placeholder: matchup.homePlaceholder, isWinner: matchup.homeIsWinner)
            VStack {
                Text("VS")
                    .font(AppTheme.Typography.condensed(.bold, size: size == .prominent ? 22 : 16))
                    .foregroundStyle(.white)
                    .frame(height: size.crestDiameter)
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
        let d = size.crestDiameter
        let gray700 = Color(white: 0.28)
        if let urlString = team?.fullImageURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFit()
                default: initialChip(name: name, diameter: d, fill: gray700)
                }
            }
            .frame(width: d, height: d)
            .clipShape(Circle())
            .overlay(Circle().stroke(gray700, lineWidth: 1))
        } else {
            initialChip(name: name, diameter: d, fill: gray700)
        }
    }

    private func initialChip(name: String, diameter: CGFloat, fill: Color) -> some View {
        Circle()
            .fill(fill)
            .frame(width: diameter, height: diameter)
            .overlay(
                Text(String(name.first.map(String.init) ?? "?").uppercased())
                    .font(AppTheme.Typography.condensed(.bold, size: diameter * 0.46))
                    .foregroundStyle(.white)
            )
            .overlay(Circle().stroke(Color(white: 0.28), lineWidth: 1))
    }

    @ViewBuilder
    private var resultRegion: some View {
        if isLive || isFinished {
            HStack(spacing: 18) {
                scoreText(matchup.homeScore, isWinner: matchup.homeIsWinner)
                Text("-").font(AppTheme.Typography.condensed(.bold, size: size.timeSize)).foregroundStyle(.white.opacity(0.5))
                scoreText(matchup.awayScore, isWinner: matchup.awayIsWinner)
            }
        } else {
            VStack(spacing: 4) {
                if let time = matchup.scheduledTime {
                    Text(Self.dateFormatter.string(from: time).uppercased())
                        .font(AppTheme.Typography.condensed(.medium, size: size.dateSize))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.8))
                    Text(Self.timeFormatter.string(from: time))
                        .font(AppTheme.Typography.condensed(.bold, size: size.timeSize))
                        .foregroundStyle(.white)
                }
            }
        }
    }

    private func scoreText(_ score: Int?, isWinner: Bool) -> some View {
        Text(score.map(String.init) ?? "-")
            .font(AppTheme.Typography.condensed(.bold, size: size.timeSize))
            .foregroundStyle(isWinner ? AppTheme.Colors.accent : .white)
    }

    private func countdownPill(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "clock").font(.system(size: 11))
            Text(text).font(AppTheme.Typography.condensed(.semibold, size: 13)).tracking(1)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 14).padding(.vertical, 7)
        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
    }

    private var divider: some View {
        Rectangle().fill(Color.white.opacity(0.15)).frame(height: 1).padding(.horizontal, 8)
    }

    @ViewBuilder
    private func venueFooter(_ venue: Venue) -> some View {
        let row = HStack(spacing: 5) {
            Image(systemName: "mappin.and.ellipse").font(.system(size: 12))
            Text(venue.name).font(AppTheme.Typography.condensed(.medium, size: 15))
        }
        .foregroundStyle(.white.opacity(0.85))

        if let mapsURL = venue.googleMapsURL {
            Button { openURL(mapsURL) } label: { row }.buttonStyle(.plain)
        } else {
            row
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
