//
//  PlayByPlayView.swift
//  Brackets
//
//  The "Play by play" section: a compact score sub-header (scrolls away) above a
//  period-grouped event log whose "PERIODO N" banners pin to the top while scrolling.
//  Meant to be dropped directly inside the screen's ScrollView so the pinned headers
//  stick to the top of the viewport.
//

import SwiftUI

struct PlayByPlayView: View {
    let periods: [PlayByPlayPeriod]
    let leftName: String
    let leftLogoURL: String?
    let rightName: String
    let rightLogoURL: String?
    let leftScore: Int
    let rightScore: Int
    /// Small label above the score (e.g. "FINAL").
    var statusLabel: String = "FINAL"

    private let hPad = AppTheme.Layout.screenPadding
    private let rowPad: CGFloat = 14
    private let corner = AppTheme.CornerRadius.large

    var body: some View {
        // One connected card: the score header (rounded top) flows straight into the
        // table below (rounded bottom). Only the period banners pin while scrolling.
        VStack(spacing: 0) {
            scoreHeader

            LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(periods) { period in
                    Section {
                        ForEach(Array(period.rows.enumerated()), id: \.element.id) { index, row in
                            // Separator sits on top of every row but the first in the
                            // period, so no full-width line crosses the rounded bottom.
                            PlayByPlayRowView(row: row, hPad: rowPad, showTopSeparator: index > 0)
                        }
                    } header: {
                        periodBanner(period.title)
                    }
                }
            }
            .background(
                UnevenRoundedRectangle(bottomLeadingRadius: corner, bottomTrailingRadius: corner)
                    .fill(AppTheme.Colors.gray800)
            )
        }
        .overlay(
            RoundedRectangle(cornerRadius: corner)
                .strokeBorder(AppTheme.Colors.gray700, lineWidth: 1)
        )
        .padding(.horizontal, hPad)
    }

    // MARK: Score header (top of the card)

    private var leftWon: Bool { leftScore > rightScore }
    private var rightWon: Bool { rightScore > leftScore }

    private var scoreHeader: some View {
        HStack(spacing: AppTheme.Spacing.small) {
            teamChip(name: leftName, logoURL: leftLogoURL, alignment: .leading)

            VStack(spacing: 2) {
                Text(statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(3)
                    .foregroundStyle(AppTheme.Colors.gray400)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    scoreNumber(leftScore, winner: leftWon)
                    Text("-")
                        .font(AppTheme.Typography.condensed(.semibold, size: 26))
                        .foregroundStyle(AppTheme.Colors.gray500)
                    scoreNumber(rightScore, winner: rightWon)
                }
                .fixedSize()
            }

            teamChip(name: rightName, logoURL: rightLogoURL, alignment: .trailing)
        }
        .padding(AppTheme.Layout.cardPadding)
        .frame(maxWidth: .infinity)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: corner, topTrailingRadius: corner)
                .fill(AppTheme.Colors.gray700)
        )
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.black.opacity(0.3)).frame(height: 1)
        }
    }

    private func scoreNumber(_ value: Int, winner: Bool) -> some View {
        Text("\(value)")
            .font(AppTheme.Typography.condensed(.semibold, size: 38))
            .foregroundStyle(winner ? AppTheme.Colors.accent : AppTheme.Colors.gray500)
    }

    private func teamChip(name: String, logoURL: String?, alignment: HorizontalAlignment) -> some View {
        VStack(spacing: 6) {
            logoCircle(urlString: logoURL, name: name, size: 40)
            Text(name)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .lineLimit(1)
                .truncationMode(.tail)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    // MARK: Pinned period banner

    private func periodBanner(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(AppTheme.Colors.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(AppTheme.Colors.gray700)
    }

    // MARK: Shared logo circle

    @ViewBuilder
    private func logoCircle(urlString: String?, name: String, size: CGFloat) -> some View {
        if let urlString, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(white: 0.22), lineWidth: 1))
                default:
                    initialsCircle(name: name, size: size)
                }
            }
        } else {
            initialsCircle(name: name, size: size)
        }
    }

    private func initialsCircle(name: String, size: CGFloat) -> some View {
        let initials = name.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
        return Circle()
            .fill(Color(white: 0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(initials.isEmpty ? "?" : initials)
                    .font(.system(size: size * 0.34, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.primaryText)
            )
            .overlay(Circle().stroke(Color(white: 0.22), lineWidth: 1))
    }
}

// MARK: - Row

private struct PlayByPlayRowView: View {
    let row: PlayByPlayRow
    let hPad: CGFloat
    var showTopSeparator: Bool = true

    private var actionColor: Color {
        switch row.actionKind {
        case .entra: return AppTheme.Colors.accent
        case .salePerdida: return AppTheme.Colors.live
        case .scoring, .neutral: return AppTheme.Colors.gray400
        }
    }

    /// First word of the first name + first word of the last name (e.g. "Mauricio Jose
    /// Castro Dominguez" -> "Mauricio Castro").
    private var playerName: String {
        let first = row.playerFirstName.split(separator: " ").first.map(String.init) ?? ""
        let last = row.playerLastName.split(separator: " ").first.map(String.init) ?? ""
        return "\(first) \(last)".trimmingCharacters(in: .whitespaces)
    }

    var body: some View {
        HStack(spacing: 10) {
            logoAvatar(size: 36)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    nameLine
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text("- \(row.actionLabel)")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(actionColor)
                        .fixedSize()
                        .layoutPriority(1)
                }
                Text(row.teamName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.Colors.gray400)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if row.showsScore {
                scorePair
            }
        }
        .padding(.leading, 8)
        .padding(.trailing, hPad)
        .padding(.vertical, 17)
        .overlay(alignment: .top) {
            if showTopSeparator {
                Rectangle()
                    .fill(AppTheme.Colors.gray700)
                    .frame(height: 1)
            }
        }
    }

    private var nameLine: Text {
        let number = row.playerNumber.map { "#\($0) " } ?? ""
        return Text(number)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(AppTheme.Colors.gray400)
            + Text(playerName)
            .font(.system(size: 15, weight: .bold))
            .foregroundColor(AppTheme.Colors.primaryText)
    }

    private var scorePair: some View {
        HStack(spacing: 3) {
            Text("\(row.leftScore)")
                .foregroundStyle(row.emphasis == .left ? AppTheme.Colors.primaryText : AppTheme.Colors.gray500)
            Text("-")
                .foregroundStyle(AppTheme.Colors.gray500)
            Text("\(row.rightScore)")
                .foregroundStyle(row.emphasis == .right ? AppTheme.Colors.primaryText : AppTheme.Colors.gray500)
        }
        .font(AppTheme.Typography.condensed(.bold, size: 22))
        .monospacedDigit()
    }

    @ViewBuilder
    private func logoAvatar(size: CGFloat) -> some View {
        if let urlString = row.fullTeamLogoURL, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color(white: 0.2), lineWidth: 1))
                default:
                    avatarFallback(size: size)
                }
            }
        } else {
            avatarFallback(size: size)
        }
    }

    private func avatarFallback(size: CGFloat) -> some View {
        Circle()
            .fill(Color(white: 0.15))
            .frame(width: size, height: size)
            .overlay(
                Text(row.playerNumber.map { "\($0)" } ?? "?")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundStyle(Color(white: 0.5))
            )
    }
}

// MARK: - Preview

#Preview {
    let rows2P = [
        PlayByPlayRow(id: 1, playerNumber: 3, playerFirstName: "Mateo", playerLastName: "Ruiz",
                      teamName: "Eagles", teamLogo: nil, actionLabel: "3 puntos", actionKind: .scoring,
                      leftScore: 28, rightScore: 40, emphasis: .right),
        PlayByPlayRow(id: 2, playerNumber: 7, playerFirstName: "Pedro", playerLastName: "Orozco",
                      teamName: "Lions", teamLogo: nil, actionLabel: "2 puntos", actionKind: .scoring,
                      leftScore: 28, rightScore: 37, emphasis: .left),
        PlayByPlayRow(id: 3, playerNumber: 21, playerFirstName: "Carlos", playerLastName: "Nieto",
                      teamName: "Eagles", teamLogo: nil, actionLabel: "Sale", actionKind: .salePerdida,
                      leftScore: 28, rightScore: 37, emphasis: .none),
        PlayByPlayRow(id: 4, playerNumber: 3, playerFirstName: "Mateo", playerLastName: "Ruiz",
                      teamName: "Eagles", teamLogo: nil, actionLabel: "Entra", actionKind: .entra,
                      leftScore: 28, rightScore: 37, emphasis: .none),
        PlayByPlayRow(id: 5, playerNumber: 12, playerFirstName: "David", playerLastName: "Grados",
                      teamName: "Lions", teamLogo: nil, actionLabel: "Falta personal (2)", actionKind: .neutral,
                      leftScore: 26, rightScore: 37, emphasis: .none)
    ]
    let rows1P = [
        PlayByPlayRow(id: 6, playerNumber: 33, playerFirstName: "Andrés", playerLastName: "Meza",
                      teamName: "Lions", teamLogo: nil, actionLabel: "Tiro libre", actionKind: .scoring,
                      leftScore: 14, rightScore: 16, emphasis: .left)
    ]
    return ScrollView {
        PlayByPlayView(
            periods: [
                PlayByPlayPeriod(id: "2P", title: "PERIODO 2", rows: rows2P),
                PlayByPlayPeriod(id: "1P", title: "PERIODO 1", rows: rows1P)
            ],
            leftName: "Lions", leftLogoURL: nil,
            rightName: "Eagles", rightLogoURL: nil,
            leftScore: 28, rightScore: 40
        )
    }
    .background(AppTheme.Colors.background)
    .preferredColorScheme(.dark)
}
