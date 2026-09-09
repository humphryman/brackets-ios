import SwiftUI

/// The four-layer animated card background: dark base, static team split,
/// three screen-blended moving blobs, and a scrim. Honors reduced motion and
/// stops animating when off-screen or backgrounded.
struct FinalCardBackground: View {
    let colorA: Color
    let colorB: Color
    var cornerRadius: CGFloat = 16

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var animate = false

    private var motionEnabled: Bool { !reduceMotion && scenePhase == .active && animate }

    var body: some View {
        ZStack {
            // Layers 1–3 composite together so `.screen` adds light onto the base.
            ZStack {
                base                      // layer 1
                staticSplit               // layer 2
                if !reduceMotion {        // layer 3 (skipped under reduced motion)
                    blobs
                }
            }
            .compositingGroup()

            scrim                          // layer 4
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .onAppear { animate = true }
        .onDisappear { animate = false }
    }

    // Layer 1 — near-black radial base.
    private var base: some View {
        RadialGradient(
            colors: [Color(white: 0.10), Color(white: 0.02)],
            center: .center, startRadius: 0, endRadius: 420
        )
    }

    // Layer 2 — static diagonal split, ~100°, 26% alpha per edge.
    private var staticSplit: some View {
        LinearGradient(
            stops: [
                .init(color: colorA.opacity(0.26), location: 0.0),
                .init(color: .clear, location: 0.5),
                .init(color: colorB.opacity(0.26), location: 1.0),
            ],
            startPoint: UnitPoint(x: -0.02, y: 0.15),   // ~100° diagonal
            endPoint: UnitPoint(x: 1.02, y: 0.85)
        )
    }

    // Layer 3 — three screen-blended blobs.
    private var blobs: some View {
        ZStack {
            blob(color: colorA, anchor: .leading,  duration: 7.0,  phase: 0)
            blob(color: colorB, anchor: .trailing, duration: 9.45, phase: 1)
            blob(color: blend(colorA, colorB), anchor: .center, duration: 4.9, phase: 2)
        }
        .blendMode(.screen)
    }

    private func blob(color: Color, anchor: UnitPoint, duration: Double, phase: Int) -> some View {
        let on = motionEnabled
        // Each blob rests off its own edge and drifts within ±95x / ±120y.
        let baseX: CGFloat = anchor == .leading ? -120 : anchor == .trailing ? 120 : 0
        let dx: CGFloat = on ? (anchor == .trailing ? -95 : 95) : 0
        let dy: CGFloat = on ? (phase == 1 ? 120 : -120) : 0
        return RadialGradient(
            colors: [color, .clear],
            center: .center, startRadius: 0, endRadius: 200
        )
        .frame(width: 330, height: 400)
        .blur(radius: 44)
        .scaleEffect(on ? 1.35 : 1.0)
        .opacity(on ? 1.0 : 0.5)
        .offset(x: baseX + dx, y: dy)
        .animation(
            on ? .easeInOut(duration: duration).repeatForever(autoreverses: true) : .default,
            value: on
        )
    }

    // Layer 4 — vertical scrim + vignette to guarantee text contrast.
    private var scrim: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black.opacity(0.55), Color.black.opacity(0.15), Color.black.opacity(0.55)],
                startPoint: .top, endPoint: .bottom
            )
            RadialGradient(
                colors: [.clear, Color.black.opacity(0.45)],
                center: .center, startRadius: 120, endRadius: 480
            )
        }
    }

    private func blend(_ a: Color, _ b: Color) -> Color {
        let ua = UIColor(a), ub = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ua.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        ub.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return Color(red: Double((r1 + r2) / 2), green: Double((g1 + g2) / 2), blue: Double((b1 + b2) / 2))
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        FinalCardBackground(colorA: Color(hex: 0xE06A1A), colorB: Color(hex: 0x8B3A62))
            .frame(width: 360, height: 620)
    }
}
