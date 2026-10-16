import SwiftUI
import SCYDECore

struct SettingsView: View {
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var cacheBytes: Int64 = 0
    @State private var showPrivacy = false

    private static var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0"
    }

    private static var build: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "0"
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    GlassIconButton(systemName: "chevron.left", label: "Back", size: 38) { dismiss() }
                    Spacer()
                    Text("Settings")
                        .font(.ui(17, .semibold, fixed: true))
                        .foregroundColor(SX.C.ink)
                    Spacer()
                    Color.clear.frame(width: 38, height: 38)
                }
                .padding(.top, 8)
                .padding(.bottom, 26)

                sectionTitle("Preferences")
                VStack(spacing: 0) {
                    row("App language") {
                        value("English")
                    }
                    divider
                    row("Appearance") {
                        Menu {
                            Picker("Appearance", selection: $app.appearance) {
                                ForEach(AppModel.Appearance.allCases) { option in
                                    Label(option.label, systemImage: option.icon).tag(option)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                value(app.appearance.label)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(SX.C.muted)
                            }
                        }
                    }
                    divider
                    row("Default format") {
                        Menu {
                            Picker("Default format", selection: $app.defaultAspect) {
                                ForEach(CanvasAspect.allCases, id: \.self) { Text($0.label).tag($0) }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                value(app.defaultAspect.label)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(SX.C.muted)
                            }
                        }
                    }
                    divider
                    row("Haptics") {
                        Toggle("", isOn: $app.hapticsEnabled)
                            .labelsHidden()
                            .tint(SX.C.accent)
                    }
                }
                .sxCard(radius: SX.R.l)
                .padding(.bottom, 30)

                sectionTitle("Feedback & about")
                VStack(spacing: 0) {
                    linkRow("Website", "https://scyde.net")
                    divider
                    linkRow("Developer", "https://scyde.dev")
                    divider
                    Button { showPrivacy = true } label: {
                        row("Privacy") { chevron }
                    }
                    .buttonStyle(.plain)
                    divider
                    Button {
                        StorageInfo.clearCaches()
                        ThumbnailCache.shared.removeAll()
                        cacheBytes = StorageInfo.cacheDirectories.reduce(Int64(0)) { $0 + StorageInfo.folder($1).bytes }
                        Haptics.success()
                        app.showToast("Cache cleared")
                    } label: {
                        row("Clear cache") { value(StorageInfo.formatter.string(fromByteCount: cacheBytes)) }
                    }
                    .buttonStyle(.plain)
                    divider
                    row("Version") { value("\(Self.version) (\(Self.build))") }
                }
                .sxCard(radius: SX.R.l)

                Text("SCYDE: Photo & Video Editor · \(Self.version)")
                    .font(.mono(11))
                    .foregroundColor(SX.C.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 30)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(SX.C.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            cacheBytes = StorageInfo.cacheDirectories.reduce(Int64(0)) { $0 + StorageInfo.folder($1).bytes }
        }
        .sheet(isPresented: $showPrivacy) {
            PrivacySheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: Row helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.display(21))
            .foregroundColor(SX.C.ink)
            .padding(.bottom, 12)
    }

    private var divider: some View {
        Divider().overlay(SX.C.line).padding(.leading, 16)
    }

    private var chevron: some View {
        Image(systemName: "chevron.right")
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(SX.C.muted)
    }

    private func value(_ text: String) -> some View {
        Text(text)
            .font(.ui(15))
            .foregroundColor(SX.C.muted)
    }

    private func row<Trailing: View>(_ title: String, @ViewBuilder trailing: () -> Trailing) -> some View {
        HStack {
            Text(title)
                .font(.ui(16))
                .foregroundColor(SX.C.ink)
            Spacer()
            trailing()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .contentShape(Rectangle())
    }

    private func linkRow(_ title: String, _ url: String) -> some View {
        Link(destination: URL(string: url)!) {
            row(title) {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SX.C.muted)
            }
        }
    }
}

private struct PrivacySheet: View {
    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text("Privacy")
                    .font(.display(26))
                    .foregroundColor(SX.C.ink)
                Text("SCYDE has no account and no servers. Photos and videos you import are copied into the app on this iPhone and never uploaded. Projects, media and settings stay on the device until you delete them or remove the app.")
                    .font(.ui(15))
                    .foregroundColor(SX.C.body)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(24)
        }
    }
}
