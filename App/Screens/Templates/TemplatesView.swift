import PhotosUI
import SwiftUI
import UIKit
import SCYDECore

struct TemplatesView: View {
    @EnvironmentObject private var app: AppModel
    @State private var query = ""
    @State private var category: TemplateCategory?
    @State private var chosen: ProjectTemplate?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var results: [ProjectTemplate] {
        ProjectTemplate.all.filter { t in
            (category == nil || t.category == category) &&
                (query.isEmpty
                    || t.name.localizedCaseInsensitiveContains(query)
                    || t.summary.localizedCaseInsensitiveContains(query)
                    || t.category.title.loc.localizedCaseInsensitiveContains(query))
        }
    }

    /// One template per category for the featured carousel.
    private var featured: [ProjectTemplate] {
        var seen = Set<TemplateCategory>()
        var out: [ProjectTemplate] = []
        for t in ProjectTemplate.all.reversed() where !seen.contains(t.category) && t.title != nil {
            seen.insert(t.category)
            out.append(t)
        }
        return Array(out.prefix(6))
    }

    /// Results split into two columns, balancing their heights.
    private func column(_ index: Int) -> [ProjectTemplate] {
        var heights: [CGFloat] = [0, 0]
        var cols: [[ProjectTemplate]] = [[], []]
        for t in results {
            let h = TemplateCard.previewHeight(t) + 56
            let c = heights[0] <= heights[1] ? 0 : 1
            cols[c].append(t)
            heights[c] += h
        }
        return cols[index]
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Templates")
                        .font(.display(30))
                        .foregroundColor(SX.C.ink)
                    Spacer()
                    Text("\(ProjectTemplate.all.count)")
                        .font(.mono(12, medium: true))
                        .foregroundColor(SX.C.muted)
                }
                .padding(.top, 12)
                .padding(.horizontal, 16)

                SearchField(placeholder: "Search templates", text: $query)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        FilterChip(title: "All", selected: category == nil) {
                            Haptics.selection()
                            withAnimation(SX.spring) { category = nil }
                        }
                        ForEach(TemplateCategory.allCases) { c in
                            Button {
                                Haptics.selection()
                                withAnimation(SX.spring) { category = c }
                            } label: {
                                HStack(spacing: 6) {
                                    Text(c.emoji)
                                        .font(.system(size: 14))
                                    Text(c.title.loc)
                                        .font(.ui(14, .medium, fixed: true))
                                }
                                .foregroundColor(category == c ? SX.C.ink : SX.C.body)
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(Capsule().fill(category == c ? SX.C.glass : Color.clear))
                                .overlay(
                                    Capsule().strokeBorder(category == c ? SX.C.ink.opacity(0.8) : SX.C.line2, lineWidth: category == c ? 1.5 : 1)
                                )
                            }
                            .buttonStyle(PressableStyle(scale: 0.95))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 2)
                }

                if results.isEmpty {
                    Text("No templates match \"\(query)\".")
                        .font(.ui(14))
                        .foregroundColor(SX.C.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    if category == nil && query.isEmpty {
                        FeaturedTemplates(templates: featured) { t in
                            Haptics.light()
                            chosen = t
                        }
                        .padding(.top, 2)
                    }
                    // Masonry: each column stacks cards at their own aspect, like a feed.
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(0..<2, id: \.self) { col in
                            LazyVStack(spacing: 16) {
                                ForEach(column(col)) { template in
                                    TemplateCard(template: template) {
                                        Haptics.light()
                                        chosen = template
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 24)
        }
        .background(SX.C.bg.ignoresSafeArea())
        .sheet(item: $chosen) { template in
            TemplateSheet(template: template)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if let name = Launch.sheet, name.hasPrefix("template:"),
               let t = ProjectTemplate.all.first(where: { $0.id == String(name.dropFirst(9)) }) {
                Task {
                    try? await Task.sleep(nanoseconds: 600_000_000)
                    chosen = t
                }
            }
        }
    }
}

private struct TemplateCard: View {
    let template: ProjectTemplate
    let action: () -> Void

    /// Card preview height from the template's shape (taller for 9:16, shorter for 16:9).
    static func previewHeight(_ t: ProjectTemplate) -> CGFloat {
        let width = (UIScreen.main.bounds.width - 44) / 2
        return min(300, max(120, width / CGFloat(t.aspect.ratio)))
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                TemplatePreviewView(template: template)
                    .frame(height: Self.previewHeight(template))
                    .clipShape(RoundedRectangle(cornerRadius: SX.R.l, style: .continuous))
                    .overlay(alignment: .topLeading) {
                        HStack(spacing: 4) {
                            Text(template.category.emoji)
                            Text(template.category.title.loc)
                        }
                        .font(.mono(9.5, medium: true))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                        .padding(9)
                    }
                    .overlay(alignment: .bottomLeading) {
                        HStack(spacing: 4) {
                            Image(systemName: "scissors")
                            Text("\(template.slots.count)")
                        }
                        .font(.mono(10, medium: true))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.4)))
                        .padding(9)
                    }
                    .shadow(color: SX.C.shadow, radius: 14, x: 0, y: 8)
                Text(template.name.loc)
                    .font(.ui(15, .semibold))
                    .foregroundColor(SX.C.ink)
                    .lineLimit(1)
                Text("\(template.aspect.label) · \(Timecode.duration(template.totalDuration))\(template.transition.map { " · " + $0.title.loc } ?? "")")
                    .font(.mono(10.5))
                    .foregroundColor(SX.C.muted)
                    .lineLimit(1)
            }
        }
        .buttonStyle(PressableStyle(scale: 0.97))
        .accessibilityLabel("\(template.name), \(template.slots.count) clips")
    }
}

struct TemplateSheet: View {
    let template: ProjectTemplate
    @EnvironmentObject private var app: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var items: [PhotosPickerItem] = []
    @State private var building = false

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        HStack(spacing: 6) {
                            Text(template.category.emoji)
                            Text(template.category.title.loc)
                        }
                        .font(.mono(11, medium: true))
                        .foregroundColor(SX.C.accent)
                        Spacer()
                        GlassIconButton(systemName: "xmark", label: "Close", size: 36) { dismiss() }
                    }
                    TemplatePreviewView(template: template)
                        .aspectRatio(CGFloat(template.aspect.ratio), contentMode: .fit)
                        .frame(maxHeight: 420)
                        .frame(maxWidth: .infinity)
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
                    HStack(spacing: 8) {
                        detail("Format", template.aspect.label)
                        detail("Clips", "\(template.slots.count)")
                        detail("Length", Timecode.duration(template.totalDuration))
                    }
                    HStack(spacing: 8) {
                        detail("Transition", template.transition?.title.loc ?? "None".loc)
                        detail("Look", (Looks.presets.first { $0.id == (template.filter ?? "original") }?.name ?? "Original").loc)
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
                    Button {
                        building = true
                        Task {
                            let ok = await app.createFromTemplateWithSamples(template)
                            building = false
                            if ok { dismiss() } else { app.showToast("Sample clips need an internet connection") }
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.rectangle.on.rectangle")
                            Text("Try it with sample clips")
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                    .disabled(building)
                    Text("Clips fill the slots in the order you pick them. Videos are trimmed to each slot; you can change everything in the editor.")
                        .font(.ui(12.5))
                        .foregroundColor(SX.C.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    let credits = MediaLibrary.shared.videos(for: template.category.rawValue)
                    if !credits.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Preview footage".loc.uppercased())
                                .font(.mono(9.5, medium: true))
                                .tracking(1.2)
                                .foregroundColor(SX.C.muted)
                            ForEach(credits) { v in
                                Text("\(v.title) · \(v.author) · \(v.license)")
                                    .font(.ui(11))
                                    .foregroundColor(SX.C.muted)
                                    .lineLimit(1)
                            }
                            Text(MediaLibrary.sources(credits))
                                .font(.ui(11))
                                .foregroundColor(SX.C.muted)
                        }
                    }
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
            Text(value)
                .font(.ui(15, .semibold, fixed: true))
                .foregroundColor(SX.C.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .sxCard(radius: SX.R.m)
    }
}

/// Paged hero carousel of large, playing template previews.
private struct FeaturedTemplates: View {
    let templates: [ProjectTemplate]
    let onPick: (ProjectTemplate) -> Void
    @State private var page = 0

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $page) {
                ForEach(templates.indices, id: \.self) { i in
                    let t = templates[i]
                    Button { onPick(t) } label: {
                        ZStack(alignment: .bottomLeading) {
                            TemplatePreviewView(template: t, playsVideo: i == page)
                            LinearGradient(colors: [.clear, Color.black.opacity(0.75)], startPoint: .center, endPoint: .bottom)
                            HStack(alignment: .bottom) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(t.category.emoji) \(t.category.title.loc.uppercased())")
                                        .font(.mono(10, medium: true))
                                        .tracking(1.1)
                                        .foregroundColor(SX.C.gold)
                                    Text(t.name.loc)
                                        .font(.display(24, bold: true))
                                        .foregroundColor(.white)
                                    Text(t.summary.loc)
                                        .font(.ui(12.5))
                                        .foregroundColor(Color.white.opacity(0.8))
                                        .lineLimit(2)
                                }
                                Spacer(minLength: 8)
                                Text("Use")
                                    .font(.ui(14, .semibold, fixed: true))
                                    .foregroundColor(Color(UIColor(hex: 0x1B1530)))
                                    .padding(.horizontal, 18)
                                    .frame(height: 38)
                                    .background(Capsule().fill(SX.C.gold))
                            }
                            .padding(16)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: SX.R.xl, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: SX.R.xl, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.14), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                    .buttonStyle(PressableStyle(scale: 0.98))
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 330)
            HStack(spacing: 6) {
                ForEach(templates.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? SX.C.accent : SX.C.line2)
                        .frame(width: i == page ? 18 : 6, height: 6)
                        .animation(SX.spring, value: page)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .task {
            guard templates.count > 1 else { return }
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 6_000_000_000)
                if Task.isCancelled { break }
                withAnimation(SX.ease) { page = (page + 1) % templates.count }
            }
        }
    }
}
