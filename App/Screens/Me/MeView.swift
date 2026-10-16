import SwiftUI
import SCYDECore

enum MeRoute: Hashable {
    case settings
}

/// Real numbers about what the app keeps on this device.
struct StorageInfo {
    var projects: Int = 0
    var mediaFiles: Int = 0
    var mediaBytes: Int64 = 0
    var cacheBytes: Int64 = 0

    static func folder(_ url: URL) -> (count: Int, bytes: Int64) {
        guard let e = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey]) else {
            return (0, 0)
        }
        var count = 0
        var bytes: Int64 = 0
        for case let file as URL in e {
            let v = try? file.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard v?.isRegularFile == true else { continue }
            count += 1
            bytes += Int64(v?.fileSize ?? 0)
        }
        return (count, bytes)
    }

    static var cacheDirectories: [URL] {
        var dirs = [FileManager.default.temporaryDirectory]
        if let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first { dirs.append(caches) }
        return dirs
    }

    static func compute(projectCount: Int) -> StorageInfo {
        let media = folder(MediaStore.directory)
        let cache = cacheDirectories.reduce(Int64(0)) { $0 + folder($1).bytes }
        return StorageInfo(projects: projectCount, mediaFiles: media.count, mediaBytes: media.bytes, cacheBytes: cache)
    }

    static func clearCaches() {
        let fm = FileManager.default
        for dir in cacheDirectories {
            guard let items = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
            for item in items { try? fm.removeItem(at: item) }
        }
    }

    static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()
}

struct MeView: View {
    @EnvironmentObject private var app: AppModel
    @State private var path = NavigationPath()
    @State private var storage = StorageInfo()

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        Spacer()
                        NavigationLink(value: MeRoute.settings) {
                            GlassIcon(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                    .padding(.top, 8)

                    HStack(spacing: 18) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: [SX.C.brand, SX.C.brand2], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 84, height: 84)
                            (Text("s").foregroundColor(SX.C.onBrand) + Text(".").foregroundColor(SX.C.gold))
                                .font(.display(38, bold: true, fixed: true))
                                .offset(y: -3)
                        }
                        .shadow(color: SX.C.brand.opacity(0.35), radius: 18, x: 0, y: 8)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Your studio")
                                .font(.display(24))
                                .foregroundColor(SX.C.ink)
                            Text("No account needed. Everything stays on this iPhone.")
                                .font(.ui(14))
                                .foregroundColor(SX.C.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        stat("Projects", "\(storage.projects)", icon: "film.stack")
                        stat("Media", "\(storage.mediaFiles)", icon: "photo.stack")
                        stat("Storage", StorageInfo.formatter.string(fromByteCount: storage.mediaBytes), icon: "internaldrive")
                    }

                    VStack(spacing: 0) {
                        MeRow(icon: "folder", title: "Projects") { app.tab = .projects }
                        Divider().overlay(SX.C.line).padding(.leading, 52)
                        MeRow(icon: "rectangle.stack", title: "Templates") { app.tab = .templates }
                        Divider().overlay(SX.C.line).padding(.leading, 52)
                        MeLinkRow(icon: "globe", title: "scyde.net", url: "https://scyde.net")
                        Divider().overlay(SX.C.line).padding(.leading, 52)
                        MeLinkRow(icon: "hammer", title: "Made by SCYDE · scyde.dev", url: "https://scyde.dev")
                    }
                    .sxCard(radius: SX.R.l)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .background(
                ZStack {
                    SX.C.bg
                    LinearGradient(colors: [SX.C.glowB, .clear], startPoint: .top, endPoint: .center)
                }
                .ignoresSafeArea()
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: MeRoute.self) { _ in
                SettingsView()
            }
        }
        .onAppear {
            storage = StorageInfo.compute(projectCount: app.projects.count)
            if Launch.screen == "settings" && path.isEmpty {
                path.append(MeRoute.settings)
            }
        }
    }

    private func stat(_ title: String, _ value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(SX.C.accent)
            Text(value)
                .font(.ui(19, .semibold, fixed: true))
                .foregroundColor(SX.C.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title.uppercased())
                .font(.mono(9.5, medium: true))
                .tracking(1.2)
                .foregroundColor(SX.C.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .sxCard(radius: SX.R.m)
    }
}

private struct MeRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SX.C.ink)
                    .frame(width: 24)
                Text(title)
                    .font(.ui(16))
                    .foregroundColor(SX.C.ink)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SX.C.muted)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct MeLinkRow: View {
    let icon: String
    let title: String
    let url: String

    var body: some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(SX.C.ink)
                    .frame(width: 24)
                Text(title)
                    .font(.ui(16))
                    .foregroundColor(SX.C.ink)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(SX.C.muted)
            }
            .padding(.horizontal, 16)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
    }
}
