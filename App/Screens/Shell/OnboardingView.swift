import SwiftUI

/// First-run introduction: four short pages, then straight into the app.
struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    private struct Page: Identifiable {
        let id: Int
        let icon: String
        let title: String
        let text: String
        let chips: [String]
    }

    private let pages: [Page] = [
        Page(id: 0, icon: "sparkles", title: "Welcome to SCYDE", text: "A full video and photo editor that works on your iPhone, not in someone's cloud.", chips: []),
        Page(id: 1, icon: "scissors", title: "Cut, style, animate", text: "Trim on a precise timeline, add keyframes, masks, effects, transitions and speed ramps.", chips: ["Keyframes", "Masks", "32 effects", "Speed curves", "Stabilise"]),
        Page(id: 2, icon: "textformat", title: "Words and stickers", text: "Styled titles with animations, auto captions, read-aloud voices and stickers you place with your fingers.", chips: ["24 fonts", "Animations", "Captions", "Text to speech"]),
        Page(id: 3, icon: "metronome", title: "Sound and rhythm", text: "Music, voice-over and voice effects. SCYDE finds the beat and can cut your clips to it.", chips: ["Beat sync", "Voice FX", "Fades"]),
        Page(id: 4, icon: "lock.shield", title: "Private by design", text: "Your media stays on this iPhone. No account, no upload, no watermark.", chips: []),
    ]

    var body: some View {
        ZStack {
            Color(UIColor(hex: 0x0D0F14)).ignoresSafeArea()
            AuroraBackground().ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    (Text("scyde").foregroundColor(.white) + Text(".").foregroundColor(SX.C.gold))
                        .font(.display(24, bold: true, fixed: true))
                    Spacer()
                    if page < pages.count - 1 {
                        Button("Skip") { finish() }
                            .font(.ui(15, .medium, fixed: true))
                            .foregroundColor(Color.white.opacity(0.75))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 12)

                TabView(selection: $page) {
                    ForEach(pages) { p in
                        pageView(p).tag(p.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                HStack(spacing: 8) {
                    ForEach(pages) { p in
                        Capsule()
                            .fill(p.id == page ? SX.C.gold : Color.white.opacity(0.25))
                            .frame(width: p.id == page ? 22 : 7, height: 7)
                    }
                }
                .animation(SX.spring, value: page)
                .padding(.bottom, 22)

                Button {
                    Haptics.light()
                    if page < pages.count - 1 {
                        withAnimation(SX.ease) { page += 1 }
                    } else {
                        finish()
                    }
                } label: {
                    Text(page < pages.count - 1 ? "Continue" : "Start editing")
                }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
        .environment(\.colorScheme, .dark)
    }

    private func finish() {
        Haptics.success()
        onDone()
    }

    private func pageView(_ p: Page) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            Image(systemName: p.icon)
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(Color(UIColor(hex: 0x1B1530)))
                .frame(width: 76, height: 76)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(colors: [Color(UIColor(hex: 0xFFE7A0)), Color(UIColor(hex: 0xE9B84A))], startPoint: .top, endPoint: .bottom))
                )
                .shadow(color: SX.C.gold.opacity(0.45), radius: 24, x: 0, y: 10)
            Text(p.title.loc)
                .font(.display(34, bold: true))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)
            Text(p.text.loc)
                .font(.ui(17))
                .foregroundColor(Color(UIColor(hex: 0xB8B4DD)))
                .fixedSize(horizontal: false, vertical: true)
            if !p.chips.isEmpty {
                FlowChips(items: p.chips)
            }
            Spacer()
            Spacer()
        }
        .padding(.horizontal, 28)
    }
}

/// Simple wrapping row of small labels.
private struct FlowChips: View {
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 8) {
                    ForEach(row, id: \.self) { item in
                        Text(item.loc)
                            .font(.mono(12, medium: true))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 30)
                            .background(Capsule().fill(Color.white.opacity(0.10)))
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    }
                }
            }
        }
    }

    /// Three per row keeps it simple and predictable on every width.
    private var rows: [[String]] {
        stride(from: 0, to: items.count, by: 3).map { Array(items[$0..<min($0 + 3, items.count)]) }
    }
}
