//
//  AppConfig.swift
//  Brackets
//
//  Created by Humberto on 16/02/26.
//

import SwiftUI

/// Centralized configuration for the entire Brackets app
/// Contains all app-wide settings, colors, API configuration, and visual parameters
enum AppConfig {
    
    // MARK: - App Information
    
    static let appName = "Brackets"
    static let appVersion = "1.0.0"
    
    // MARK: - API Configuration
    
    enum API {
        private static var isProduction: Bool {
            #if DEBUG
            return false
            #else
            return true
            #endif
        }
        
        static var baseURL: String {
            if isProduction {
                // TODO: Replace with your production API URL
                return "https://api.yourapp.com"
            } else {
                return "http://127.0.0.1:3000"
            }
        }
        
        static var apiURL: String {
            "\(baseURL)/api"
        }
        
        // Network timeouts
        static let requestTimeout: TimeInterval = 30
        static let resourceTimeout: TimeInterval = 60
    }
    
    // MARK: - Design System
    
    enum Design {
        
        // MARK: Colors
        
        /// Bright lime green - Main accent color throughout the app
        /// Used for: badges, highlights, winner indicators, interactive elements
        /// Hex: #C7F24A | RGB: (199, 242, 74)
        static let accentColor = Color(red: 0.78, green: 0.95, blue: 0.29)
        
        /// Dark backgrounds
        static let primaryBackground = Color.black
        static let secondaryBackground = Color(white: 0.12)
        static let tertiaryBackground = Color(white: 0.2)
        
        /// Text colors
        static let primaryText = Color.white
        static let secondaryText = Color.gray
        static let accentText = Color.black // Text on accent color backgrounds
        
        /// Status colors
        static let positiveColor = accentColor
        static let negativeColor = Color.red
        static let warningColor = Color.orange
        static let neutralColor = Color.white
        
        /// UI element colors
        static let separatorColor = Color(white: 0.2)
        static let borderColor = Color(white: 0.3)
        
        // MARK: Typography Sizes
        
        static let fontSizeLargeTitle: CGFloat = 32
        static let fontSizeTitle: CGFloat = 28
        static let fontSizeHeadline: CGFloat = 18
        static let fontSizeBody: CGFloat = 16
        static let fontSizeCaption: CGFloat = 14
        static let fontSizeSmallCaption: CGFloat = 12
        static let fontSizeTinyCaption: CGFloat = 10
        
        // MARK: Spacing
        
        static let spacingExtraSmall: CGFloat = 4
        static let spacingSmall: CGFloat = 8
        static let spacingMedium: CGFloat = 12
        static let spacingStandard: CGFloat = 16
        static let spacingLarge: CGFloat = 20
        static let spacingExtraLarge: CGFloat = 24
        static let spacingHuge: CGFloat = 32
        
        // MARK: Corner Radius
        
        static let cornerRadiusSmall: CGFloat = 8
        static let cornerRadiusMedium: CGFloat = 12
        static let cornerRadiusLarge: CGFloat = 16
        static let cornerRadiusExtraLarge: CGFloat = 20
        static let cornerRadiusMax: CGFloat = 1000 // For capsule shapes
        
        // MARK: Layout
        
        static let cardPadding: CGFloat = 16
        static let screenPadding: CGFloat = 12
        static let screenPaddingLarge: CGFloat = 24
        static let sectionSpacing: CGFloat = 20
        static let itemSpacing: CGFloat = 16
        
        // MARK: Animation Durations
        
        static let animationDurationQuick: Double = 0.2
        static let animationDurationStandard: Double = 0.3
        static let animationDurationSlow: Double = 0.5
        
        // Spring animation parameters
        static let springResponse: Double = 0.4
        static let springDamping: Double = 0.7
        
        // MARK: UI Element Sizes
        
        static let positionCircleSize: CGFloat = 36
        static let teamImageSize: CGFloat = 56
        static let teamImageWinnerBorderSize: CGFloat = 64
        static let teamImageBorderWidth: CGFloat = 3
        
        static let backButtonSize: CGFloat = 40
        static let iconSizeLarge: CGFloat = 48
        static let iconSizeStandard: CGFloat = 24
        static let iconSizeSmall: CGFloat = 16
    }
    
    // MARK: - Feature Flags
    
    enum Features {
        static let enableAnalytics = false
        static let enableCrashReporting = false
        static let showDebugInfo = false
        
        #if DEBUG
        static let enableLogging = true
        #else
        static let enableLogging = false
        #endif
    }
    
    // MARK: - App Settings
    
    enum Settings {
        static let defaultLanguage = "es" // Spanish
        static let supportedLanguages = ["es", "en"]
        
        // Cache settings
        static let imageCacheDuration: TimeInterval = 86400 // 24 hours
        static let dataCacheDuration: TimeInterval = 3600 // 1 hour
        
        // Pagination
        static let defaultPageSize = 20
        static let maxPageSize = 100
    }
}

// MARK: - Convenience Extensions

extension Color {
    /// Brackets app accent color (lime green #C7F24A)
    static let bracketsAccent = AppConfig.Design.accentColor
    
    /// Brackets primary background (black)
    static let bracketsPrimaryBackground = AppConfig.Design.primaryBackground
    
    /// Brackets card background (dark gray)
    static let bracketsCardBackground = AppConfig.Design.secondaryBackground
}

extension Animation {
    /// Standard app animation (ease in/out 0.3s)
    static let bracketsStandard = Animation.easeInOut(duration: AppConfig.Design.animationDurationStandard)
    
    /// Quick app animation (ease in/out 0.2s)
    static let bracketsQuick = Animation.easeInOut(duration: AppConfig.Design.animationDurationQuick)
    
    /// Slow app animation (ease in/out 0.5s)
    static let bracketsSlow = Animation.easeInOut(duration: AppConfig.Design.animationDurationSlow)
    
    /// Spring animation with app parameters
    static let bracketsSpring = Animation.spring(
        response: AppConfig.Design.springResponse,
        dampingFraction: AppConfig.Design.springDamping
    )
}
