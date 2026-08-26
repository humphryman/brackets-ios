//
//  ShareFonts.swift
//  Brackets
//
//  Barlow Condensed (SIL Open Font License 1.1 — see Brackets/Fonts/OFL.txt).
//  Poppins (SIL Open Font License 1.1 — see Brackets/Fonts/OFL-Poppins.txt).
//

import CoreText
import SwiftUI
import UIKit

/// The app's bundled type, registered at runtime: Barlow Condensed for titles and
/// numerals, and Poppins Black — the design system's `Display` face — for the champion.
///
/// Registration is done in code rather than via the `UIAppFonts` Info.plist key for the
/// same reason `LSApplicationQueriesSchemes` was avoided: this target sets
/// `GENERATE_INFOPLIST_FILE = YES` and has no Info.plist, and `INFOPLIST_KEY_*` build
/// settings cannot express an array cleanly. `CTFontManagerRegisterGraphicsFont` needs
/// no plist entry at all — the .ttf files just have to be in the bundle, which the
/// synchronized file group handles automatically.
enum ShareFont {

    enum Weight: String, CaseIterable {
        case regular   = "BarlowCondensed-Regular"
        case medium    = "BarlowCondensed-Medium"
        case semibold  = "BarlowCondensed-SemiBold"
        case bold      = "BarlowCondensed-Bold"
        case extraBold = "BarlowCondensed-ExtraBold"
    }

    /// `Display` in the design system. Reserved for naming the champion — nothing else
    /// uses it, so it ships as the single Black weight rather than a family.
    enum Display: String, CaseIterable {
        case black = "Poppins-Black"
    }

    /// Every bundled face, by resource name.
    private static var bundledFaces: [String] {
        Weight.allCases.map(\.rawValue) + Display.allCases.map(\.rawValue)
    }

    private static var didRegister = false

    /// Registers the bundled faces once. Safe to call repeatedly and from any point
    /// before the first render; `condensed(_:size:)` calls it for you.
    static func registerIfNeeded() {
        guard !didRegister else { return }
        didRegister = true

        for face in bundledFaces {
            guard let url = Bundle.main.url(forResource: face, withExtension: "ttf") else {
                // Never fatal: the accessors fall back to the system font, so a missing
                // face costs typography, not a working screen.
                debugPrint("ShareFont: missing resource \(face).ttf")
                continue
            }
            var error: Unmanaged<CFError>?
            // `.process` scope: available to this process, no plist declaration needed.
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // Already-registered is benign; anything else is worth knowing about.
                let cfError = error?.takeRetainedValue()
                let code = (cfError as Error?).map { ($0 as NSError).code }
                if code != Int(CTFontManagerError.alreadyRegistered.rawValue) {
                    debugPrint("ShareFont: could not register \(face): \(String(describing: cfError))")
                }
            }
        }
    }

    /// Barlow Condensed at `size`, falling back to the system font if registration failed
    /// so a missing resource degrades to a plain number rather than a blank card.
    static func condensed(_ weight: Weight, size: CGFloat) -> Font {
        registerIfNeeded()

        if UIFont(name: weight.rawValue, size: size) != nil {
            return .custom(weight.rawValue, size: size)
        }
        return .system(size: size, weight: .bold, design: .default)
    }

    /// Poppins Black at `size` — the design system's `Display` face. Falls back to the
    /// system font at `.black` so a missing resource degrades to a heavy title rather
    /// than a mismatched one.
    static func display(_ weight: Display = .black, size: CGFloat) -> Font {
        registerIfNeeded()

        if UIFont(name: weight.rawValue, size: size) != nil {
            return .custom(weight.rawValue, size: size)
        }
        return .system(size: size, weight: .black, design: .default)
    }

    /// Big-number treatment: condensed, tight, and non-scaling so a 3-digit score keeps
    /// the same optical weight as a 2-digit one.
    static func score(size: CGFloat) -> Font {
        condensed(.bold, size: size)
    }
}
