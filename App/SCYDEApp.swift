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

struct RootView: View {
    @EnvironmentObject private var app: AppModel

    var body: some View {
        HomeView()
            .fullScreenCover(item: $app.openProject) { project in
                EditorView(
                    project: project,
                    onSave: { app.save($0) },
                    onClose: { app.closeEditor() }
                )
                .preferredColorScheme(app.appearance.scheme)
            }
    }
}
