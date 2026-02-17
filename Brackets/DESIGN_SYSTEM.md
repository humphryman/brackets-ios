# Brackets App - Design System & Configuration

## Overview

The Brackets app uses a centralized configuration system to ensure consistency across all views and components. This document explains the design system and how to use it.

## Configuration Files

### 1. AppConfig.swift
**The main configuration file** containing all app-wide settings:

- **API Configuration**: Base URLs, endpoints, timeouts
- **Design System**: Colors, spacing, typography, animations
- **Feature Flags**: Enable/disable features
- **App Settings**: Language, caching, pagination

#### Usage Example:
```swift
// Using the accent color
Text("Hello")
    .foregroundStyle(AppConfig.Design.accentColor)

// Using spacing
.padding(.horizontal, AppConfig.Design.spacingLarge)

// Using animations
.animation(.bracketsStandard, value: someValue)

// Accessing API
let url = "\(AppConfig.API.apiURL)/tournaments"
```

### 2. AppTheme.swift
**SwiftUI-specific theme components** including:

- Pre-configured color palettes
- Typography styles
- Spacing values
- Corner radius values
- Reusable UI components (PositionCircle, RecordBadge, ScoreText, etc.)
- View modifiers

#### Usage Example:
```swift
// Using theme components
Text("Title")
    .font(AppTheme.Typography.headline)
    .foregroundStyle(AppTheme.Colors.primaryText)

// Using reusable components
AppTheme.PositionCircle(position: 1)
AppTheme.RecordBadge(record: "5-2")

// Using view modifiers
VStack {
    // content
}
.cardStyle()
```

## Design System

### Color Palette

#### Primary Colors
- **Accent Color**: `#C7F24A` (Lime Green)
  - RGB: (199, 242, 74)
  - Usage: Badges, highlights, winner indicators, interactive elements
  - This is the signature color of the app - use it for emphasis!

#### Backgrounds
- **Primary**: Black (`#000000`)
- **Secondary**: Dark Gray (`rgb(0.12, 0.12, 0.12)`)
- **Tertiary**: Medium Gray (`rgb(0.2, 0.2, 0.2)`)

#### Text Colors
- **Primary Text**: White
- **Secondary Text**: Gray
- **Accent Text**: Black (for text on lime green backgrounds)

#### Status Colors
- **Positive**: Lime Green (accent color)
- **Negative**: Red
- **Warning**: Orange
- **Neutral**: White

### Typography Scale

| Style | Size | Weight | Usage |
|-------|------|--------|-------|
| Large Title | 32pt | Bold | Main screen titles |
| Title | 28pt | Bold | Section headers |
| Headline | 18pt | Bold | Card titles, important labels |
| Body | 16pt | Regular | Standard text |
| Body Bold | 16pt | Bold | Emphasized body text |
| Caption | 14pt | Regular | Supporting text |
| Small Caption | 12pt | Semibold | Labels, stats |
| Tiny Caption | 10pt | Semibold | Tiny labels |

### Spacing Scale

| Name | Value | Usage |
|------|-------|-------|
| Extra Small | 4pt | Tight spacing within components |
| Small | 8pt | Small gaps |
| Medium | 12pt | Medium gaps |
| Standard | 16pt | Default spacing |
| Large | 20pt | Section spacing |
| Extra Large | 24pt | Screen padding, major sections |
| Huge | 32pt | Large separations |

### Corner Radius

| Name | Value | Usage |
|------|-------|-------|
| Small | 8pt | Small elements |
| Medium | 12pt | Standard cards |
| Large | 16pt | Large cards |
| Extra Large | 20pt | Prominent cards |
| Max (Pill) | 1000pt | Capsule shapes |

## Reusable Components

### AppTheme.PositionCircle
Displays a position number in a lime green circle.

```swift
AppTheme.PositionCircle(position: 1, size: 36)
```

### AppTheme.RecordBadge
Shows a win-loss record in a lime green pill.

```swift
AppTheme.RecordBadge(record: "5-2", fontSize: 14)
```

### AppTheme.ScoreText
Displays a score in the accent color.

```swift
AppTheme.ScoreText(score: 21, size: 32)
```

### AppTheme.LoadingView
Standard loading spinner with optional message.

```swift
AppTheme.LoadingView(message: "Loading games...")
```

### AppTheme.ErrorView
Error display with retry button.

```swift
AppTheme.ErrorView(message: "Failed to load data") {
    // Retry action
    await loadData()
}
```

### AppTheme.EmptyStateView
Empty state with icon and message.

```swift
AppTheme.EmptyStateView(
    icon: "sportscourt",
    message: "No games available"
)
```

## View Modifiers

### .cardStyle()
Applies standard card styling with padding and background.

```swift
VStack {
    Text("Card content")
}
.cardStyle()
```

### .accentButtonStyle()
Applies lime green button styling.

```swift
Button("Tap me") { }
    .accentButtonStyle()
```

## Animations

Pre-configured animations for consistency:

```swift
// Standard (0.3s ease in/out)
.animation(.bracketsStandard, value: someValue)

// Quick (0.2s ease in/out)
.animation(.bracketsQuick, value: someValue)

// Slow (0.5s ease in/out)
.animation(.bracketsSlow, value: someValue)

// Spring
.animation(.bracketsSpring, value: someValue)
```

## Best Practices

### ✅ Do:
- Always use `AppTheme` or `AppConfig` for colors, spacing, and typography
- Use reusable components when available
- Use semantic color names (e.g., `primaryText` not `white`)
- Use spacing constants instead of magic numbers
- Apply `.cardStyle()` modifier for cards

### ❌ Don't:
- Hardcode colors like `Color.white` or `Color(red: 0.5, green: 0.5, blue: 0.5)`
- Hardcode spacing values like `.padding(16)`
- Hardcode font sizes like `.font(.system(size: 18))`
- Create custom variants of standard components without good reason

### Migration Guide

If you have existing code with hardcoded values:

**Before:**
```swift
Text("Title")
    .font(.system(size: 18, weight: .bold))
    .foregroundStyle(.white)
    .padding(16)
```

**After:**
```swift
Text("Title")
    .font(AppTheme.Typography.headline)
    .foregroundStyle(AppTheme.Colors.primaryText)
    .padding(AppTheme.Spacing.standard)
```

## Color Usage Examples

### The Lime Green Accent (#C7F24A)

This is your signature color! Use it for:

1. **Record Badges** - Win/loss records (e.g., "5-2")
2. **Position Indicators** - Rankings and positions
3. **Winner Highlights** - Winning team scores and borders
4. **Point Differentials** - Positive stats
5. **Interactive Elements** - Buttons, selected states
6. **Trophy Icons** - Awards and achievements

**Example - Winner Score:**
```swift
Text("\(score)")
    .foregroundStyle(isWinner ? AppTheme.Colors.accent : AppTheme.Colors.secondaryText)
```

**Example - Record Badge:**
```swift
AppTheme.RecordBadge(record: "5-2") // Automatically lime green
```

## File Organization

```
Brackets/
├── Config/
│   ├── AppConfig.swift          # Main configuration
│   └── APIConfig.swift          # Legacy API config (redirects to AppConfig)
├── Theme/
│   └── AppTheme.swift           # SwiftUI theme components
├── Views/
│   ├── StandingsView.swift
│   ├── GameCardView.swift
│   └── ...
└── Models/
    └── ...
```

## Questions?

- For color questions: Check `AppConfig.Design` or `AppTheme.Colors`
- For spacing questions: Check `AppConfig.Design` or `AppTheme.Spacing`
- For API configuration: Check `AppConfig.API`
- For reusable components: Check `AppTheme` extensions

---

**Last Updated:** February 16, 2026
