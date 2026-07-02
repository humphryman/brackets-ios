//
//  ClassificationView.swift
//  Brackets
//
//  Playoff seeding table ("Tabla de clasificación"): order-by-place across all
//  groups, showing which teams classify into which bracket and their seed.
//

import SwiftUI

// MARK: - Bracket color palette

/// Per-bracket colors, assigned by bracket order (position). Drives the seed
/// badge circle and the legend pill for each bracket.
struct ClassificationBracketColor {
    let badgeFill: Color   // solid seed-badge circle
    let badgeText: Color   // number inside the circle
    let pillFill: Color    // legend pill background
    let pillText: Color    // legend pill text
}

enum ClassificationPalette {
    static let entries: [ClassificationBracketColor] = [
        // 1 — green (accent)
        ClassificationBracketColor(
            badgeFill: AppTheme.Colors.accent,
            badgeText: AppTheme.Colors.accentText,
            pillFill: AppTheme.Colors.accent.opacity(0.18),
            pillText: AppTheme.Colors.accent
        ),
        // 2 — blue / indigo (#1A17D3)
        ClassificationBracketColor(
            badgeFill: Color(red: 0.102, green: 0.090, blue: 0.827),
            badgeText: .white,
            pillFill: Color(red: 0.102, green: 0.090, blue: 0.827).opacity(0.35),
            pillText: Color(red: 0.68, green: 0.72, blue: 1.0)
        ),
        // 3 — orange / amber
        ClassificationBracketColor(
            badgeFill: Color(red: 0.94, green: 0.62, blue: 0.11),
            badgeText: .black,
            pillFill: Color(red: 0.94, green: 0.62, blue: 0.11).opacity(0.18),
            pillText: Color(red: 0.96, green: 0.72, blue: 0.28)
        ),
        // 4 — purple
        ClassificationBracketColor(
            badgeFill: Color(red: 0.63, green: 0.36, blue: 0.95),
            badgeText: .white,
            pillFill: Color(red: 0.63, green: 0.36, blue: 0.95).opacity(0.30),
            pillText: Color(red: 0.78, green: 0.58, blue: 1.0)
        ),
        // 5 — teal
        ClassificationBracketColor(
            badgeFill: Color(red: 0.13, green: 0.71, blue: 0.67),
            badgeText: .black,
            pillFill: Color(red: 0.13, green: 0.71, blue: 0.67).opacity(0.22),
            pillText: Color(red: 0.34, green: 0.83, blue: 0.79)
        ),
    ]

    static func entry(for index: Int?) -> ClassificationBracketColor? {
        guard let index else { return nil }
        return entries[index % entries.count]
    }
}

// MARK: - Column layout

private enum ClassCol {
    static let seed: CGFloat = 40      // seed badge circle column
    static let badge: CGFloat = 34     // circle diameter
    static let place: CGFloat = 24
    static let avg: CGFloat = 64
    static let hSpacing: CGFloat = 8
}

// MARK: - AVG pill (es_MX comma format)

/// AVG value on a green/red-tinted pill, formatted with a comma decimal (es_MX)
/// and monospaced digits to match the classification mockup.
struct ClassificationAvgPill: View {
    let value: Double?

    private static let formatter: NumberFormatter = {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "es_MX")
        f.numberStyle = .decimal
        f.minimumFractionDigits = 3
        f.maximumFractionDigits = 3
        return f
    }()

    private var text: String {
        guard let value else { return "-" }
        return Self.formatter.string(from: NSNumber(value: value)) ?? String(format: "%.3f", value)
    }

    private var color: Color {
        guard let value else { return AppTheme.Colors.neutral }
        return value >= 1 ? AppTheme.Colors.accent : AppTheme.Colors.negative
    }

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
            )
    }
}

// MARK: - Legend card

/// One bracket's legend: "#{position} · {name}" + a colored capacity pill.
struct ClassificationLegendCard: View {
    let bracket: ClassificationBracket
    let color: ClassificationBracketColor

    private var pillText: String {
        let label = bracket.typeLabel ?? bracket.type ?? ""
        return "\(label) \(bracket.filled)/\(bracket.capacity)"
    }

    var body: some View {
        HStack(spacing: 10) {
            (
                Text("#\(bracket.position) · ")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(AppTheme.Colors.primaryText)
                + Text(bracket.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(AppTheme.Colors.primaryText)
            )
            .lineLimit(1)
            .minimumScaleFactor(0.7)

            Text(pillText)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(color.pillText)
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(color.pillFill))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.1))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
    }
}

// MARK: - Team row

struct ClassificationRow: View {
    let team: ClassificationTeam
    let color: ClassificationBracketColor?

    private var groupText: String? { team.group }

    var body: some View {
        HStack(spacing: ClassCol.hSpacing) {
            seedBadge
                .frame(width: ClassCol.seed)

            Text(team.name)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.Colors.primaryText)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let groupText {
                Text(groupText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule().fill(Color(red: 0.180, green: 0.051, blue: 0.031))
                    )
            }

            Text(team.place.map(String.init) ?? "")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: ClassCol.place)

            ClassificationAvgPill(value: team.avg)
                .frame(width: ClassCol.avg)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .opacity(team.classified ? 1 : 0.55)
    }

    @ViewBuilder
    private var seedBadge: some View {
        if let color, let seed = team.seed {
            Text("\(seed)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color.badgeText)
                .frame(width: ClassCol.badge, height: ClassCol.badge)
                .background(Circle().fill(color.badgeFill))
        } else {
            Text("—")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .frame(width: ClassCol.badge, height: ClassCol.badge)
        }
    }
}

// MARK: - Classification panel

struct ClassificationView: View {
    let classification: Classification

    /// Brackets in position order; index drives the color palette.
    private var orderedBrackets: [ClassificationBracket] {
        classification.brackets.sorted { $0.position < $1.position }
    }

    /// Bracket name → palette index (position order).
    private var bracketColorIndex: [String: Int] {
        var map: [String: Int] = [:]
        for (index, bracket) in orderedBrackets.enumerated() {
            map[bracket.name] = index
        }
        return map
    }

    private var classifiedTeams: [ClassificationTeam] {
        classification.teams.filter { $0.classified }
    }

    private var unclassifiedTeams: [ClassificationTeam] {
        classification.teams.filter { !$0.classified }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                legend
                table
            }
            .padding(.top, AppTheme.Spacing.small)
            .padding(.bottom, AppTheme.Layout.large)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tabla de clasificación")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text("Orden por lugar a través de los grupos. Los equipos resaltados clasifican.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.Colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legend: some View {
        VStack(spacing: 10) {
            ForEach(Array(orderedBrackets.enumerated()), id: \.element.id) { index, bracket in
                ClassificationLegendCard(
                    bracket: bracket,
                    color: ClassificationPalette.entries[index % ClassificationPalette.entries.count]
                )
                .padding(.horizontal, 6)
            }
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            // Column-label band
            HStack(spacing: ClassCol.hSpacing) {
                Text("#").frame(width: ClassCol.seed, alignment: .center)
                Text("EQUIPO").frame(maxWidth: .infinity, alignment: .leading)
            }
            .font(AppTheme.Typography.tinyCaption)
            .foregroundStyle(AppTheme.Colors.secondaryText)
            .textCase(.uppercase)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(StandingsSurface.header)

            // Rows
            VStack(spacing: 0) {
                ForEach(Array(rowItems.enumerated()), id: \.offset) { index, item in
                    if index > 0 {
                        Divider().overlay(AppTheme.Colors.separator)
                    }
                    switch item {
                    case .team(let team):
                        ClassificationRow(
                            team: team,
                            color: ClassificationPalette.entry(for: bracketColorIndex[team.bracket ?? ""])
                        )
                    case .band:
                        Text("No clasificados")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.secondaryText)
                            .textCase(.uppercase)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(StandingsSurface.header)
                    }
                }
            }
            .background(StandingsSurface.rows)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large))
        .padding(.horizontal, 6)
    }

    private enum RowItem {
        case team(ClassificationTeam)
        case band
    }

    private var rowItems: [RowItem] {
        var items = classifiedTeams.map { RowItem.team($0) }
        if !unclassifiedTeams.isEmpty {
            items.append(.band)
            items.append(contentsOf: unclassifiedTeams.map { RowItem.team($0) })
        }
        return items
    }
}
