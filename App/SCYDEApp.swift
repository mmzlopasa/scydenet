import SwiftUI
import SCYDECore

@main
struct SCYDEApp: App {
    @StateObject private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(app)
                .preferredColorScheme(app.appearance.scheme)
                .tint(SX.C.accent)
        }
    }
}
