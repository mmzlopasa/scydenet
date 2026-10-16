import PhotosUI
import SwiftUI
import UIKit
import SCYDECore

/// A built-in project structure: a format plus clip slots with fixed lengths.
struct ProjectTemplate: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
    let aspect: CanvasAspect
    let slots: [Double]
    let colors: [UInt32]

    var totalDuration: Double { slots.reduce(0, +) }

    static let all: [ProjectTemplate] = [
        ProjectTemplate(id: "slideshow", name: "Quick slideshow", summary: "Six moments, evenly paced.", aspect: .portrait9x16, slots: Array(repeating: 1.5, count: 6), colors: [0xC4BBFF, 0x5A49E6]),
        ProjectTemplate(id: "trio", name: "Story trio", summary: "Three clips with room to breathe.", aspect: .portrait9x16, slots: [3, 3, 3], colors: [0xFFE7A0, 0xE9B84A]),
        ProjectTemplate(id: "beat", name: "Beat cut", summary: "Eight fast cuts for music edits.", aspect: .portrait9x16, slots: Array(repeating: 0.8, count: 8), colors: [0xFFB4C0, 0x7A3A6A]),
        ProjectTemplate(id: "wide", name: "Wide recap", summary: "Five shots for a landscape recap.", aspect: .landscape16x9, slots: Array(repeating: 2.5, count: 5), colors: [0xA9C8FF, 0x3D4FB8]),
        ProjectTemplate(id: "square", name: "Square carousel", summary: "Four square frames, two seconds each.", aspect: .square1x1, slots: [2, 2, 2, 2], colors: [0x8EF0C8, 0x2B6F7A]),
        ProjectTemplate(id: "reel", name: "Portrait reel", summary: "A 4:5 reel with a slower finish.", aspect: .portrait4x5, slots: [2, 2, 3, 2, 3], colors: [0xC4BBFF, 0xE9B84A]),
        ProjectTemplate(id: "day", name: "Day in ten", summary: "Ten one-second snapshots.", aspect: .portrait9x16, slots: Array(repeating: 1, count: 10), colors: [0xFFD76A, 0x5A49E6]),
        ProjectTemplate(id: "cinema", name: "Cinema open", summary: "Three wide 21:9 shots.", aspect: .cinema21x9, slots: [4, 3, 4], colors: [0x262A35, 0xFFD76A]),
    ]
}

struct TemplatesView: View {
    @EnvironmentObject private var app: AppModel
    @State private var query = ""
    @State private var filter: CanvasAspect?
    @State private var chosen: ProjectTemplate?

    private let filters: [(String, CanvasAspect?)] = [
        ("All", nil), ("Vertical", .portrait9x16), ("Wide", .landscape16x9), ("Square", .square1x1), ("Portrait", .portrait4x5),
    ]
    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    private var results: [ProjectTemplate] {
        ProjectTemplate.all.filter { t in
            (filter == nil || t.aspect == filter) &&
                (query.isEmpty || t.name.localizedCaseInsensitiveContains(query) || t.summary.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Templates")
                        .font(.display(30))
                        .foregroundColor(SX.C.ink)
                    Text("Pick a structure, add your clips. Everything stays editable.")
                        .font(.ui(14))
                        .foregroundColor(SX.C.body)
                }
                .padding(.top, 12)

                SearchField(placeholder: "Search templates", text: $query)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(filters.indices, id: \.self) { i in
                            FilterChip(title: filters[i].0, selected: filter == filters[i].1) {
                                Haptics.selection()
                                withAnimation(SX.spring) { filter = filters[i].1 }
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }

                if results.isEmpty {
                    Text("No templates match \"\(query)\".")
                        .font(.ui(14))
                        .foregroundColor(SX.C.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(results) { template in
                            TemplateCard(template: template) {
                                Haptics.light()
                                chosen = template
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .background(SX.C.bg.ignoresSafeArea())
        .sheet(item: $chosen) { template in
            TemplateSheet(template: template)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

/// Procedural cover art: the template's colours plus one bar per clip slot.
struct TemplateArt: View {
    let template: ProjectTemplate

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: template.colors.map { Color(UIColor(hex: $0)) },
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            RadialGradient(colors: [Color.white.opacity(0.35), .clear], center: .topTrailing, startRadius: 0, endRadius: 260)
            GeometryReader { geo in
                let r = CGFloat(template.aspect.ratio)
                let maxW = geo.size.width * 0.62
                let maxH = geo.size.height * 0.52
                let w = min(maxW, maxH * r)
                let h = w / r
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
                    .frame(width: w, height: h)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.42)
            }
            HStack(spacing: 3) {
                ForEach(template.slots.indices, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.85))
                        .frame(maxWidth: .infinity)
                        .frame(height: 8)
                }
            }
            .padding(10)
        }
    }
}

private struct TemplateCard: View {
    let template: ProjectTemplate
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                TemplateArt(template: template)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: SX.R.l, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        Text("\(template.slots.count) clips")
                            .font(.mono(10, medium: true))
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Color.black.opacity(0.35)))
                            .padding(10)
                    }
                    .shadow(color: SX.C.shadow, radius: 16, x: 0, y: 10)
                Text(template.name.loc)
                    .font(.ui(16, .semibold))
                    .foregroundColor(SX.C.ink)
                    .lineLimit(1)
                Text("\(template.aspect.label) · \(Timecode.duration(template.totalDuration))")
                    .font(.mono(11))
                    .foregroundColor(SX.C.muted)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel("\(template.name), \(template.slots.count) clips")
    }
}

private struct TemplateSheet: View {
    let template: ProjectTemplate
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []
    @State private var building = false

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        GlassIconButton(systemName: "xmark", label: "Close", size: 36) { dismiss() }
                    }
                    TemplateArt(template: template)
                        .frame(height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: SX.R.xl, style: .continuous))
                        .shadow(color: SX.C.shadow, radius: 24, x: 0, y: 14)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(template.name.loc)
                            .font(.display(28))
                            .foregroundColor(SX.C.ink)
                        Text(template.summary.loc)
                            .font(.ui(15))
                            .foregroundColor(SX.C.body)
                    }
                    HStack(spacing: 10) {
                        detail("Format", template.aspect.label)
                        detail("Clips", "\(template.slots.count)")
                        detail("Length", Timecode.duration(template.totalDuration))
                    }
                    PhotosPicker(
                        selection: $items,
                        maxSelectionCount: template.slots.count,
                        matching: .any(of: [.videos, .images])
                    ) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 15, weight: .bold))
                            Text("Choose \(template.slots.count) photos or videos")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(building)
                    Text("Clips fill the slots in the order you pick them. Videos are trimmed to each slot; you can change everything in the editor.")
                        .font(.ui(12.5))
                        .foregroundColor(SX.C.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 30)
            }
            if building {
                Color.black.opacity(0.45).ignoresSafeArea()
                VStack(spacing: 12) {
                    ProgressView().tint(SX.C.accent).scaleEffect(1.2)
                    Text("Building your project")
                        .font(.ui(14, .medium, fixed: true))
                        .foregroundColor(SX.C.ink)
                }
                .padding(.horizontal, 30)
                .padding(.vertical, 22)
                .sxCard(radius: SX.R.l)
            }
        }
        .onChange(of: items) { picked in
            guard !picked.isEmpty, !building else { return }
            building = true
            Task {
                let ok = await app.createFromTemplate(template, items: picked)
                building = false
                items = []
                if ok {
                    dismiss()
                } else {
                    app.showToast("Could not import those items")
                }
            }
        }
    }

    private func detail(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.loc.uppercased())
                .font(.mono(9.5, medium: true))
                .tracking(1.2)
                .foregroundColor(SX.C.muted)
            Text(value.loc)
                .font(.ui(16, .semibold, fixed: true))
                .foregroundColor(SX.C.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .sxCard(radius: SX.R.m)
    }
}
