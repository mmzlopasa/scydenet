import SwiftUI
import UIKit

struct AILabView: View {
    @EnvironmentObject private var app: AppModel

    private struct Feature: Identifiable {
        let id: String
        let icon: String
        let title: String
        let detail: String
        let open: @MainActor (AppModel) -> Void
    }

    private let features: [Feature] = [
        Feature(id: "captions", icon: "captions.bubble", title: "Auto captions", detail: "Speech to text, offline") { $0.openEditorTool("Captions") },
        Feature(id: "cutout", icon: "person.crop.rectangle", title: "Remove background", detail: "Person cut-out with Vision") { $0.openPhotoEditor(tab: 3) },
        Feature(id: "autocut", icon: "wand.and.stars", title: "AutoCut", detail: "Drop silences and dead air") { $0.openEditorTool("AutoCut") },
        Feature(id: "enhance", icon: "sparkles", title: "Auto enhance", detail: "Exposure and colour in one tap") { $0.openPhotoEditor(tab: 1) },
        Feature(id: "voice", icon: "waveform", title: "Voice effects", detail: "Pitch, echo, radio") { $0.openEditorTool("Voice FX") },
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                Text("What are we\nmaking today?")
                    .font(.display(34, bold: true))
                    .foregroundColor(SX.C.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 40)

                onDeviceCard

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(features) { feature in
                        Button {
                            feature.open(app)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: feature.icon)
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(SX.C.ink)
                                    .frame(width: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(feature.title)
                                        .font(.ui(16, .medium))
                                        .foregroundColor(SX.C.ink)
                                    Text(feature.detail)
                                        .font(.ui(12.5))
                                        .foregroundColor(SX.C.muted)
                                }
                                Spacer(minLength: 8)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(SX.C.muted)
                            }
                            .padding(.horizontal, 18)
                            .padding(.vertical, 14)
                            .background(Capsule().fill(SX.C.glass))
                            .overlay(Capsule().strokeBorder(SX.C.line2, lineWidth: 1))
                        }
                        .buttonStyle(PressableStyle(scale: 0.97))
                        .accessibilityLabel(feature.title)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(
            ZStack {
                SX.C.bg
                RadialGradient(colors: [SX.C.glowA, .clear], center: .topTrailing, startRadius: 0, endRadius: 420)
            }
            .ignoresSafeArea()
        )
    }

    private var onDeviceCard: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(SX.accentGradient)
                    .frame(width: 54, height: 54)
                    .shadow(color: SX.C.accent.opacity(0.45), radius: 14, x: 0, y: 6)
                Image(systemName: "iphone")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(SX.C.onAccent)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("Runs on your iPhone")
                    .font(.display(17))
                    .foregroundColor(SX.C.ink)
                Text("SCYDE's AI tools work offline. Your clips are never uploaded.")
                    .font(.ui(13))
                    .foregroundColor(SX.C.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sxCard(radius: SX.R.l)
    }
}
