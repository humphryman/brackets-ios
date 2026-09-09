import SwiftUI
import UIKit
import CoreGraphics

/// A color in HSL, the space the card design reasons in. `hue` is 0..360,
/// `saturation` and `lightness` are 0..1.
struct HSLColor: Equatable, Sendable {
    var hue: Double
    var saturation: Double
    var lightness: Double

    var color: Color {
        // Convert HSL -> RGB.
        let c = (1 - abs(2 * lightness - 1)) * saturation
        let hp = hue / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let (r1, g1, b1): (Double, Double, Double)
        switch hp {
        case 0..<1:  (r1, g1, b1) = (c, x, 0)
        case 1..<2:  (r1, g1, b1) = (x, c, 0)
        case 2..<3:  (r1, g1, b1) = (0, c, x)
        case 3..<4:  (r1, g1, b1) = (0, x, c)
        case 4..<5:  (r1, g1, b1) = (x, 0, c)
        default:     (r1, g1, b1) = (c, 0, x)
        }
        let m = lightness - c / 2
        return Color(red: r1 + m, green: g1 + m, blue: b1 + m)
    }
}

/// Shortest angular distance between two hues, 0..180.
func hueDistance(_ a: Double, _ b: Double) -> Double {
    let d = abs(a - b).truncatingRemainder(dividingBy: 360)
    return d > 180 ? 360 - d : d
}

enum TeamColorExtractor {

    /// Extracts a single dominant, lifted brand color from a logo, or nil if
    /// nothing survives the filters (e.g. an all-gray or all-black crest).
    static func extractDominant(_ image: UIImage, side: Int = 48) -> HSLColor? {
        guard let pixels = downscaledRGBA(image, side: side) else { return nil }

        var buckets: [Int: (count: Int, r: Double, g: Double, b: Double)] = [:]
        let count = side * side
        for i in 0..<count {
            let o = i * 4
            let r = Double(pixels[o]) / 255
            let g = Double(pixels[o + 1]) / 255
            let b = Double(pixels[o + 2]) / 255
            let a = Double(pixels[o + 3]) / 255
            if a < 200.0 / 255.0 { continue }

            let (h, s, l) = rgbToHSL(r, g, b)
            if l < 0.12 || l > 0.92 { continue }
            if s < 0.25 { continue }

            // Bucket by rounding each channel down to a multiple of 16.
            let key = (Int(r * 255) / 16) << 16 | (Int(g * 255) / 16) << 8 | (Int(b * 255) / 16)
            var entry = buckets[key] ?? (0, 0, 0, 0)
            entry.count += 1
            entry.r += r; entry.g += g; entry.b += b
            buckets[key] = entry
            _ = h
        }

        guard let best = buckets.max(by: { a, b in
            a.value.count != b.value.count ? a.value.count < b.value.count : a.key > b.key
        }), best.value.count > 0 else {
            return nil
        }
        let n = Double(best.value.count)
        let (h, s, l) = rgbToHSL(best.value.r / n, best.value.g / n, best.value.b / n)

        // Lift into the usable band. Sampled colors only — callers must not
        // lift the fallback palette values.
        return HSLColor(
            hue: h,
            saturation: max(s, 0.55),
            lightness: min(max(l, 0.42), 0.62)
        )
    }

    /// Draws `image` into a `side`×`side` RGBA8 buffer and returns the raw bytes.
    private static func downscaledRGBA(_ image: UIImage, side: Int) -> [UInt8]? {
        guard let cg = image.cgImage else { return nil }
        let bytesPerPixel = 4
        let bytesPerRow = side * bytesPerPixel
        var data = [UInt8](repeating: 0, count: side * side * bytesPerPixel)
        let space = CGColorSpaceCreateDeviceRGB()
        let info = CGImageAlphaInfo.premultipliedLast.rawValue
        guard let ctx = data.withUnsafeMutableBytes({ buf -> CGContext? in
            CGContext(
                data: buf.baseAddress,
                width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: bytesPerRow,
                space: space, bitmapInfo: info
            )
        }) else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
        return data
    }

    private static func rgbToHSL(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        guard maxV != minV else { return (0, 0, l) }
        let d = maxV - minV
        let s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
        var h: Double
        switch maxV {
        case r: h = (g - b) / d + (g < b ? 6 : 0)
        case g: h = (b - r) / d + 2
        default: h = (r - g) / d + 4
        }
        h *= 60
        return (h, s, l)
    }
}

/// Resolves the two colors a Final card paints with, applying the design's
/// separation and crestless-fallback rules. Fallback values are used as-is
/// (never lifted).
func resolveFinalPair(a: HSLColor?, b: HSLColor?) -> (Color, Color) {
    let fallback0 = Color(hex: 0x6b7280) // neutral gray
    let fallback1 = Color(hex: 0x1a2e05) // lime-950

    switch (a, b) {
    case let (a?, b?):
        var second = b
        if hueDistance(a.hue, b.hue) < 25 {
            second = HSLColor(
                hue: (b.hue + 40).truncatingRemainder(dividingBy: 360),
                saturation: b.saturation,
                lightness: b.lightness
            )
        }
        return (a.color, second.color)
    case let (a?, nil):
        return (a.color, fallback0)
    case let (nil, b?):
        return (fallback0, b.color)
    case (nil, nil):
        return (fallback0, fallback1)
    }
}
