//
//  AppTheme.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

/// Central theme configuration for the Brackets app
/// Contains all colors, fonts, spacing, and shared design elements
///
/// **Note:** This file contains the SwiftUI-specific theme components.
/// For general app configuration and design tokens, see `AppConfig.swift`
///
/// Key Design Elements:
/// - Accent Color: Neon green (#a3ff12) - used for highlights, badges, winner indicators
/// - Background: Pure black with dark gray cards
/// - Typography: System font with consistent sizing
/// - Spacing: Standardized spacing scale from 4pt to 32pt
struct AppTheme {
    
    // MARK: - Colors
    
    struct Colors {
        /// Primary accent color - Bright neon green used throughout the app
        /// Hex: #a3ff12 | RGB: (163, 255, 18)
        static let accent = Color(red: 163/255, green: 255/255, blue: 18/255)
        static let accentGradient = Color(red: 200/255, green: 255/255, blue: 40/255)
        
        /// Background colors
        static let background = Color.black
        static let cardBackground = Color(white: 0.12)
        
        /// Text colors
        static let primaryText = Color.white
        static let secondaryText = Color.gray
        static let accentText = Color.black // Text on accent color backgrounds
        
        /// Status colors
        static let positive = accent // Use accent for positive values
        static let negative = Color.red
        static let neutral = Color.white
        static let live = Color(red: 0.92, green: 0.20, blue: 0.25)
        
        /// UI Element colors
        static let separator = Color(white: 0.2)
        static let loading = accent

        /// Subtle 1pt outline for containers and tiles
        /// Hex: #252525
        static let outline = Color(red: 37/255, green: 37/255, blue: 37/255)

        /// Elevated surface fill used behind tiles and image placeholders
        /// Hex: #141414
        static let surface = Color(red: 20/255, green: 20/255, blue: 20/255)

        // MARK: Design-system palette
        // Values come from the Figma Design System file (Segmented Controller,
        // node 115:124). Named after their Figma variables so the two stay traceable.

        /// `color/gray-300` — label of an unselected segment. Hex: #D1D5DB
        static let gray300 = Color(red: 209/255, green: 213/255, blue: 219/255)

        /// `color/gray-400` — labels under a stat value. Hex: #9CA3AF
        static let gray400 = Color(red: 156/255, green: 163/255, blue: 175/255)

        /// `color/gray-600` — hairline around a segmented track. Hex: #4B5563
        static let gray600 = Color(red: 75/255, green: 85/255, blue: 99/255)

        /// `color/gray-700` — segmented track fill and card outlines. Hex: #252525,
        /// same value as `outline`.
        static let gray700 = outline

        /// `color/gray-800` — card fill. Hex: #1A1A1A
        static let gray800 = Color(red: 26/255, green: 26/255, blue: 26/255)

        /// `color/sky/sky-900` — selection accent. Hex: #1A17D3
        static let sky900 = Color(red: 26/255, green: 23/255, blue: 211/255)

        /// `color/sky/sky-900-26%` — fill behind a selected segment. Hex: #1A17D3 at 26%
        static let sky900Muted = sky900.opacity(0.26)
    }
    
    // MARK: - Typography
    
    struct Typography {
        // Headers
        static let largeTitle = Font.system(size: 32, weight: .bold)
        static let title = Font.system(size: 28, weight: .bold)
        static let headline = Font.system(size: 18, weight: .bold)
        
        // Body
        static let body = Font.system(size: 16, weight: .regular)
        static let bodyBold = Font.system(size: 16, weight: .bold)
        
        // Small text
        static let caption = Font.system(size: 14, weight: .regular)
        static let smallCaption = Font.system(size: 12, weight: .semibold)
        static let tinyCaption = Font.system(size: 10, weight: .semibold)

        /// Barlow Condensed — screen titles and section titles.
        /// Registered at runtime by `ShareFont`; falls back to the system font.
        static func condensed(_ weight: ShareFont.Weight, size: CGFloat) -> Font {
            ShareFont.condensed(weight, size: size)
        }
    }
    
    // MARK: - Spacing
    
    struct Spacing {
        static let extraSmall: CGFloat = 4
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let standard: CGFloat = 16
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 24
        static let huge: CGFloat = 32
    }
    
    // MARK: - Corner Radius
    
    struct CornerRadius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 12
        static let large: CGFloat = 16
        static let extraLarge: CGFloat = 20
        static let pill: CGFloat = 1000 // For capsule shapes
    }
    
    // MARK: - Layout
    
    struct Layout {
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 12
        static let sectionSpacing: CGFloat = 20
        static let itemSpacing: CGFloat = 16
        static let large: CGFloat = 20
        static let extraLarge: CGFloat = 24
    }
    
    // MARK: - Animation
    
    struct Animation {
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.5)
        static let spring = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.7)
    }
}

// MARK: - Shared UI Components

extension AppTheme {
    
    /// Position indicator circle used in standings and rankings
    struct PositionCircle: View {
        let position: Int
        let size: CGFloat
        
        init(position: Int, size: CGFloat = 36) {
            self.position = position
            self.size = size
        }
        
        var body: some View {
            ZStack {
                Circle()
                    .fill(AppTheme.Colors.accent)
                    .frame(width: size, height: size)
                
                Text("\(position)")
                    .font(.system(size: size * 0.44, weight: .bold))
                    .foregroundStyle(AppTheme.Colors.accentText)
            }
        }
    }
    
    /// Record badge (e.g., "5-2") used in standings and game cards
    struct RecordBadge: View {
        let record: String
        let fontSize: CGFloat
        
        init(record: String, fontSize: CGFloat = 14) {
            self.record = record
            self.fontSize = fontSize
        }
        
        var body: some View {
            Text(record)
                .font(.system(size: fontSize, weight: .bold))
                .foregroundStyle(AppTheme.Colors.accentText)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(AppTheme.Colors.accent)
                )
        }
    }
    
    /// Score display used in game cards
    struct ScoreText: View {
        let score: Int
        let size: CGFloat
        
        init(score: Int, size: CGFloat = 32) {
            self.score = score
            self.size = size
        }
        
        var body: some View {
            Text("\(score)")
                .font(.system(size: size, weight: .bold))
                .foregroundStyle(AppTheme.Colors.accent)
        }
    }
    
    /// Loading view with branded spinner
    struct LoadingView: View {
        let message: String
        
        init(message: String = "Loading...") {
            self.message = message
        }
        
        var body: some View {
            VStack(spacing: 16) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(AppTheme.Colors.loading)
                    .scaleEffect(1.5)
                
                Text(message)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    
    /// Error view with retry button
    struct ErrorView: View {
        let message: String
        let retryAction: () -> Void
        
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text(message)
                    .font(AppTheme.Typography.body)
                    .foregroundStyle(AppTheme.Colors.primaryText)
                    .multilineTextAlignment(.center)
                
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.accent)
                .foregroundStyle(AppTheme.Colors.accentText)
            }
            .padding(.horizontal, AppTheme.Spacing.extraLarge)
        }
    }
    
    // MARK: Screen Header

    /// Metrics shared by every screen header.
    enum HeaderMetrics {
        /// Side of the circular leading/trailing controls.
        static let control: CGFloat = 36

        /// Screen title size. Barlow Condensed reads smaller than the system font at the
        /// same point size, so this runs larger than the sizes it replaced.
        static let titleSize: CGFloat = 32

        /// Gap the title keeps from either control, so it is never optically crowded.
        static let titleInset: CGFloat = control + AppTheme.Spacing.small
    }

    /// Circular icon control used on the edges of `ScreenHeader`.
    struct HeaderButton: View {
        let icon: String
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: HeaderMetrics.control, height: HeaderMetrics.control)
                    .overlay {
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primaryText)
                    }
            }
        }
    }

    /// Standard screen title bar: leading control, centered title, optional trailing
    /// control. Titles are uppercased.
    ///
    /// The title is centered on the **full** width of the bar — it sits in its own layer
    /// rather than in a row with the controls, so its center never depends on which
    /// controls are present. `titleInset` keeps it clear of them: a long title shrinks to
    /// 80% to try to fit and truncates with an ellipsis after that, so it can never slide
    /// underneath the back button.
    ///
    /// Callers keep their own padding — this view only lays out the bar itself.
    struct ScreenHeader: View {
        let title: String
        var tint: Color = AppTheme.Colors.primaryText
        var leadingIcon: String? = "chevron.left"
        var onLeading: (() -> Void)?
        var trailingIcon: String?
        var onTrailing: (() -> Void)?

        var body: some View {
            ZStack {
                Text(title.uppercased())
                    .font(AppTheme.Typography.condensed(.semibold, size: HeaderMetrics.titleSize))
                    .foregroundStyle(tint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .truncationMode(.tail)
                    .padding(.horizontal, HeaderMetrics.titleInset)
                    .frame(maxWidth: .infinity)

                HStack(spacing: 0) {
                    if let leadingIcon, let onLeading {
                        HeaderButton(icon: leadingIcon, action: onLeading)
                    }

                    Spacer(minLength: 0)

                    if let trailingIcon, let onTrailing {
                        HeaderButton(icon: trailingIcon, action: onTrailing)
                    }
                }
            }
            .frame(minHeight: HeaderMetrics.control)
        }
    }

    /// Empty state view
    struct EmptyStateView: View {
        let icon: String
        let message: String
        
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 48))
                    .foregroundStyle(AppTheme.Colors.secondaryText)
                
                Text(message)
                    .font(AppTheme.Typography.headline)
                    .foregroundStyle(AppTheme.Colors.secondaryText)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

// MARK: - View Modifiers

extension View {
    /// Apply standard card styling
    func cardStyle() -> some View {
        self
            .padding(AppTheme.Layout.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.CornerRadius.large)
                    .fill(AppTheme.Colors.cardBackground)
                    .stroke(Color(white: 1.0).opacity(0.18), lineWidth: 1)
            )
    }
    
    /// Apply accent button styling
    func accentButtonStyle() -> some View {
        self
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.Colors.accent)
            .foregroundStyle(AppTheme.Colors.accentText)
    }
}
