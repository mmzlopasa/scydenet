import AVFoundation
import SwiftUI
import SCYDECore

/// Search and import free stock videos from Pexels.
struct StockSheet: View {
    @ObservedObject var model: EditorViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var videos: [Pexels.Video] = []
    @State private var loading = false
    @State private var error: String?
    @State private var keyInput = ""
    @State private var hasKey = Pexels.APIKey.load() != nil
    @State private var downloading: Int?
    @State private var topic: String?
    @State private var source = 0

    private let topics = ["Cars", "City", "Nature", "Ocean", "People", "Travel", "Food", "Sport", "Night", "Abstract"]
    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    private var orientation: Pexels.Orientation {
        let r = model.project.aspect.ratio
        if r < 0.95 { return .portrait }
        if r > 1.05 { return .landscape }
        return .square
    }

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                SheetHeader(title: "Stock videos", subtitle: "Free footage, added to your timeline.") { dismiss() }
                Picker("", selection: $source) {
                    Text("SCYDE library").tag(0)
                    Text("Pexels").tag(1)
                }
                .pickerStyle(.segmented)
                if source == 0 {
                    LibraryBrowser(model: model) { dismiss() }
                } else if hasKey {
                    browser
                } else {
                    keySetup
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .onChange(of: source) { s in
            if s == 1 && hasKey && videos.isEmpty { Task { await load() } }
        }
    }

    // MARK: Key setup

    private var keySetup: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pexels gives every user a free API key. Create one at pexels.com/api, paste it here, and SCYDE can search millions of free videos.")
                .font(.ui(14))
                .foregroundColor(SX.C.body)
                .fixedSize(horizontal: false, vertical: true)
            Link(destination: URL(string: "https://www.pexels.com/api/")!) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Get a free key at pexels.com/api")
                }
            }
            .buttonStyle(SecondaryButtonStyle())
            SecureField("Paste API key", text: $keyInput)
                .font(.mono(14))
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .padding(14)
                .sxCard(radius: SX.R.m)
            Button {
                Pexels.APIKey.save(keyInput)
                hasKey = Pexels.APIKey.load() != nil
                Task { await load() }
            } label: {
                Text("Save key")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(keyInput.trimmingCharacters(in: .whitespaces).count < 20)
            Text("The key is stored in this iPhone's Keychain. Searches go to Pexels; nothing of yours is uploaded.")
                .font(.ui(12))
                .foregroundColor(SX.C.muted)
            Spacer()
        }
    }

    // MARK: Browser

    private var browser: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SearchField(placeholder: "Search stock videos", text: $query)
                    .onSubmit { topic = nil; Task { await load() } }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "Popular", selected: topic == nil && query.isEmpty) {
                        topic = nil
                        query = ""
                        Task { await load() }
                    }
                    ForEach(topics, id: \.self) { t in
                        FilterChip(title: t, selected: topic == t) {
                            topic = t
                            query = ""
                            Task { await load() }
                        }
                    }
                }
            }
            if let error = error {
                Text(error)
                    .font(.ui(13))
                    .foregroundColor(SX.C.err)
            }
            ScrollView(showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(videos) { v in
                        Button {
                            Task { await add(v) }
                        } label: {
                            ZStack(alignment: .bottomLeading) {
                                AsyncImage(url: v.image) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        SX.C.surface3
                                    }
                                }
                                .frame(height: 150)
                                .frame(maxWidth: .infinity)
                                .clipped()
                                LinearGradient(colors: [.clear, Color.black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(Timecode.short(Double(v.duration)))
                                        .font(.mono(10, medium: true))
                                    Text(v.user.name)
                                        .font(.ui(9.5, fixed: true))
                                        .lineLimit(1)
                                        .opacity(0.85)
                                }
                                .foregroundColor(.white)
                                .padding(6)
                                if downloading == v.id {
                                    Color.black.opacity(0.5)
                                    ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(downloading != nil)
                        .accessibilityLabel("Video by \(v.user.name)")
                    }
                }
                if loading {
                    ProgressView().tint(SX.C.accent).padding(30)
                }
                Link(destination: URL(string: "https://www.pexels.com")!) {
                    Text("Videos provided by Pexels")
                        .font(.mono(11))
                        .foregroundColor(SX.C.muted)
                }
                .padding(.vertical, 16)
            }
        }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            let term = topic ?? query
            if term.isEmpty {
                videos = try await Pexels.popular()
            } else {
                videos = try await Pexels.search(term, orientation: orientation)
            }
        } catch let e as Pexels.Failure {
            error = e.localizedDescription
            if case .badKey = e {
                Pexels.APIKey.save("")
                hasKey = false
            }
        } catch {
            self.error = Pexels.Failure.network.localizedDescription
        }
    }

    private func add(_ v: Pexels.Video) async {
        downloading = v.id
        defer { downloading = nil }
        do {
            let id = try await Pexels.download(v)
            let asset = AVURLAsset(url: MediaStore.url(for: id))
            let seconds = (try? await asset.load(.duration))?.seconds ?? Double(v.duration)
            model.addStockClip(assetID: id, duration: seconds, credit: v.user.name)
            dismiss()
        } catch {
            self.error = error.localizedDescription
        }
    }
}
