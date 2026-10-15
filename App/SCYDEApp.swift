import SwiftUI
import SCYDECore

// Minimal shell so the pipeline can be validated end to end.
// Phase 2 replaces this with the real design system, Home and Editor.
@main
struct SCYDEApp: App {
    var body: some Scene {
        WindowGroup {
            SplashView()
        }
    }
}

struct SplashView: View {
    var body: some View {
        ZStack {
            Color(red: 0.051, green: 0.059, blue: 0.078).ignoresSafeArea()
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    Text("scyde")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 0.96, green: 0.95, blue: 1.0))
                    Text(".")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundColor(Color(red: 1.0, green: 0.843, blue: 0.416))
                }
                Text(Timecode.string(0))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(red: 0.56, green: 0.545, blue: 0.73))
            }
        }
    }
}
