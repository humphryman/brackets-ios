//
//  Badge.swift
//  Brackets
//

import SwiftUI

/// Badge from the Figma Design System (node `84:62`).
///
/// A capsule holding one short, uppercase-ish label — a stat abbreviation, a count, a
/// state. Six styles, all sharing the same geometry: only fill, border and label colour
/// change.
///
/// The translucent fills (30% over the accent, 6%/12% white) are raw values in Figma
/// rather than named variables, so they are derived here from the solid tokens instead of
/// being hardcoded a second time.
struct Badge: View {

    enum Style {
        /// Solid lime, black label. The Figma default.
        case lime
        /// Neutral translucent white.
        case gray
        /// Tinted `sky900`.
        case blue
        /// Tinted `orange500`.
        case orange
        /// Solid `gray800` with a hairline.
        case dark
        /// `lime900` fill with a lime border. Figma calls this one "Green outline".
        case limeOutline

        var fill: Color {
            switch self {
            case .lime:        AppTheme.Colors.lime400
            case .gray:        Color.white.opacity(0.06)
            case .blue:        AppTheme.Colors.sky900.opacity(0.3)
            case .orange:      AppTheme.Colors.orange500.opacity(0.3)
            case .dark:        AppTheme.Colors.gray800
            case .limeOutline: AppTheme.Colors.lime900
            }
        }

        /// `nil` when the style has no border.
        var border: Color? {
            switch self {
            case .lime:        nil
            case .gray:        Color.white.opacity(0.12)
            case .blue:        AppTheme.Colors.sky900
            case .orange:      AppTheme.Colors.orange500
            case .dark:        Color.white.opacity(0.12)
            case .limeOutline: AppTheme.Colors.lime400
            }
        }

        var label: Color {
            switch self {
            case .lime: AppTheme.Colors.accentText
            case .dark: AppTheme.Colors.gray300
            default:    AppTheme.Colors.primaryText
            }
        }
    }

    private enum Metrics {
        static let paddingH: CGFloat = 12
        static let paddingV: CGFloat = 6
        static let fontSize: CGFloat = 10
        static let borderWidth: CGFloat = 1
    }

    let text: String
    var style: Style = .lime

    init(_ text: String, style: Style = .lime) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(.system(size: Metrics.fontSize, weight: .semibold))
            .foregroundStyle(style.label)
            .multilineTextAlignment(.center)
            .lineLimit(1)
            // Figma marks the label `whitespace-nowrap`: the badge hugs its text and
            // never lets a tight container squeeze it into an ellipsis.
            .fixedSize()
            .padding(.horizontal, Metrics.paddingH)
            .padding(.vertical, Metrics.paddingV)
            .background(Capsule().fill(style.fill))
            .overlay {
                if let border = style.border {
                    Capsule().strokeBorder(border, lineWidth: Metrics.borderWidth)
                }
            }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Badge("Label")
        Badge("Label", style: .gray)
        Badge("Label", style: .blue)
        Badge("Label", style: .orange)
        Badge("Label", style: .dark)
        Badge("Label", style: .limeOutline)
    }
    .padding(24)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(AppTheme.Colors.background)
    .preferredColorScheme(.dark)
}
