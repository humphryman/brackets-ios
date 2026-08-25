//
//  ClassificationView.swift
//  Brackets
//
//  Playoff seeding table ("Tabla de clasificación"): order-by-place across all
//  groups, showing which teams classify into which bracket and their seed.
//

import SwiftUI

// MARK: - Bracket color palette

/// Per-bracket colors, assigned by bracket order (position). One recipe drives both the
/// legend badge and the seed circle, so a bracket reads the same in either place.
struct ClassificationBracketColor {
    let fill: Color      // circle / badge background
    let stroke: Color    // outline
    let text: Color      // number inside the circle
    let badge: Badge.Style
}

enum ClassificationPalette {
    /// Three entries, matching the three outlined `Badge` styles. Tournaments with more
    /// brackets cycle back through them.
    static let entries: [ClassificationBracketColor] = [
        ClassificationBracketColor(
            fill: AppTheme.Colors.lime900,
            stroke: AppTheme.Colors.lime400,
            text: AppTheme.Colors.primaryText,
            badge: .limeOutline
        ),
        ClassificationBracketColor(
            fill: AppTheme.Colors.sky900.opacity(0.3),
            stroke: AppTheme.Colors.sky900,
            text: AppTheme.Colors.primaryText,
            badge: .blue
        ),
        ClassificationBracketColor(
            fill: AppTheme.Colors.orange500.opacity(0.3),
            stroke: AppTheme.Colors.orange500,
            text: AppTheme.Colors.primaryText,
            badge: .orange
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

// MARK: - Legend

extension ClassificationBracket {
    /// "Gold - Octavos": bracket name and the short form of its stage.
    var badgeLabel: String {
        let stage = (typeLabel ?? type ?? "")
            .replacingOccurrences(
                of: " de final",
                with: "",
                options: [.caseInsensitive]
            )
            .trimmingCharacters(in: .whitespaces)
        return stage.isEmpty ? name : "\(name) - \(stage)"
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
                .foregroundStyle(team.classified ? AppTheme.Colors.primaryText : AppTheme.Colors.gray400)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let groupText {
                Badge(groupText, style: team.classified ? .gray : .dark)
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
    }

    @ViewBuilder
    private var seedBadge: some View {
        if let color, let seed = team.seed {
            Text("\(seed)")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color.text)
                .frame(width: ClassCol.badge, height: ClassCol.badge)
                .background(Circle().fill(color.fill))
                .overlay(Circle().strokeBorder(color.stroke, lineWidth: 1.5))
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
                .font(AppTheme.Typography.condensed(.semibold, size: 24))
                .foregroundStyle(AppTheme.Colors.primaryText)
            Text("Orden por lugar a través de los grupos. Los equipos resaltados clasifican.")
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(AppTheme.Colors.gray400)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var legend: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(orderedBrackets.enumerated()), id: \.element.id) { index, bracket in
                    Badge(
                        bracket.badgeLabel,
                        style: ClassificationPalette.entries[index % ClassificationPalette.entries.count].badge
                    )
                }
            }
            .padding(.horizontal, 14)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
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
