import SwiftUI

/// Slow two-glow background: gold top right and lavender bottom left on dark,
/// violet and gold on light. Static when Reduce Motion is on.
struct AuroraBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drift = false

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                SX.C.bg
                Circle()
                    .fill(SX.C.glowA)
                    .frame(width: w * 1.15, height: w * 1.15)
                    .blur(radius: 90)
                    .offset(x: w * 0.42 + (drift ? -24 : 18), y: -h * 0.30 + (drift ? 18 : -8))
                Circle()
                    .fill(SX.C.glowB)
                    .frame(width: w * 1.25, height: w * 1.25)
                    .blur(radius: 110)
                    .offset(x: -w * 0.48 + (drift ? 22 : -14), y: h * 0.36 + (drift ? -12 : 10))
            }
            .frame(width: w, height: h)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion, !Launch.isAutomation else { return }
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}
