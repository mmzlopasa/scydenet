import SwiftUI

/// Subscription tiers. Prices and limits live here in one place.
/// Purchases open together with SCYDE accounts; during the beta every feature is unlocked.
enum Plan: String, CaseIterable, Identifiable {
    case free, pro, team

    var id: String { rawValue }

    var name: String {
        switch self {
        case .free: return "Free"
        case .pro: return "Pro"
        case .team: return "Team"
        }
    }

    var tagline: String {
        switch self {
        case .free: return "Everything you need to edit on your phone."
        case .pro: return "For creators who publish every week."
        case .team: return "Shared brand, templates and storage for teams."
        }
    }

    /// Display prices in euro: (monthly, yearly). Team is per member.
    var price: (monthly: String, yearly: String)? {
        switch self {
        case .free: return nil
        case .pro: return ("€7.99", "€59.99")
        case .team: return ("€12.99", "€119.99")
        }
    }

    var palette: ArtPalette {
        switch self {
        case .free: return .graphite
        case .pro: return .gold
        case .team: return .violet
        }
    }

    var icon: String {
        switch self {
        case .free: return "scissors"
        case .pro: return "crown.fill"
        case .team: return "person.3.fill"
        }
    }

    var highlights: [String] {
        switch self {
        case .free: return [
            "Full timeline: trim, split, keyframes, speed",
            "Effects, filters, transitions, stickers",
            "Auto captions and text to speech",
            "Export up to 1080p 30 fps",
            "All templates with your own media",
        ]
        case .pro: return [
            "Everything in Free",
            "Export 4K and 60 fps, HEVC",
            "Pro effects, speed curves, stabilise",
            "Premium templates and the full music library",
            "Cloud backup of projects (100 GB)",
            "No SCYDE end card, ever",
        ]
        case .team: return [
            "Everything in Pro",
            "Shared brand kit: fonts, colours, logos",
            "Team templates and shared projects",
            "1 TB shared cloud storage",
            "Roles, admin and invoices",
        ]
        }
    }
}

/// Feature matrix rows: name and availability per plan.
private struct PlanFeature: Identifiable {
    let id = UUID()
    let name: String
    let values: [String]
}

struct PlansView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var yearly = true
    @State private var selected: Plan = .pro
    @State private var appeared = false

    private let matrix: [PlanFeature] = [
        PlanFeature(name: "Export resolution", values: ["1080p", "4K", "4K"]),
        PlanFeature(name: "Frame rate", values: ["30 fps", "60 fps", "60 fps"]),
        PlanFeature(name: "Effects and transitions", values: ["Core", "All", "All"]),
        PlanFeature(name: "Templates", values: ["120+", "All + premium", "All + team"]),
        PlanFeature(name: "Music library", values: ["Starter", "Full", "Full"]),
        PlanFeature(name: "Cloud backup", values: ["–", "100 GB", "1 TB shared"]),
        PlanFeature(name: "Brand kit", values: ["–", "Personal", "Shared"]),
        PlanFeature(name: "Collaboration", values: ["–", "–", "✓"]),
    ]

    var body: some View {
        ZStack {
            SX.C.bg.ignoresSafeArea()
            LinearGradient(colors: [SX.C.glowA, .clear], startPoint: .top, endPoint: .center).ignoresSafeArea()
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Spacer()
                        GlassIconButton(systemName: "xmark", label: "Close", size: 36) { dismiss() }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose your plan")
                            .font(.display(32, bold: true))
                            .foregroundColor(SX.C.ink)
                        Text("Start free. Upgrade when your videos need more.")
                            .font(.ui(15))
                            .foregroundColor(SX.C.body)
                    }
                    betaBanner
                    billingToggle
                    ForEach(Plan.allCases.indices, id: \.self) { i in
                        card(Plan.allCases[i])
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(SX.ease.delay(Double(i) * 0.08), value: appeared)
                    }
                    SectionLabel(index: "01", title: "Compare plans")
                        .padding(.top, 8)
                    comparison
                    Text("Prices include VAT where it applies. Plans renew until cancelled; you can cancel any time from your account.")
                        .font(.ui(11.5))
                        .foregroundColor(SX.C.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
            }
        }
        .onAppear { appeared = true }
    }

    private var betaBanner: some View {
        HStack(spacing: 12) {
            ArtIcon(symbol: "gift.fill", palette: .mint, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Beta: everything is unlocked")
                    .font(.ui(15, .semibold, fixed: true))
                    .foregroundColor(SX.C.ink)
                Text("Subscriptions open together with SCYDE accounts (Google, Apple or email).")
                    .font(.ui(12.5))
                    .foregroundColor(SX.C.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sxCard(radius: SX.R.l)
    }

    private var billingToggle: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { y in
                Button {
                    Haptics.selection()
                    withAnimation(SX.spring) { yearly = y }
                } label: {
                    HStack(spacing: 6) {
                        Text(y ? "Yearly" : "Monthly")
                            .font(.ui(14, .semibold, fixed: true))
                        if y {
                            Text("−37%")
                                .font(.mono(10, medium: true))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(SX.C.ok.opacity(0.2)))
                                .foregroundColor(SX.C.ok)
                        }
                    }
                    .foregroundColor(yearly == y ? SX.C.onAccent : SX.C.ink)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(
                        Capsule().fill(yearly == y ? AnyShapeStyle(SX.accentGradient) : AnyShapeStyle(Color.clear))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Capsule().fill(SX.C.glass))
        .overlay(Capsule().strokeBorder(SX.C.line2, lineWidth: 1))
    }

    private func card(_ plan: Plan) -> some View {
        let isSelected = selected == plan
        return Button {
            Haptics.selection()
            withAnimation(SX.spring) { selected = plan }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ArtIcon(symbol: plan.icon, palette: plan.palette, size: 46)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 8) {
                            Text(plan.name.loc)
                                .font(.display(22, bold: true))
                                .foregroundColor(SX.C.ink)
                            if plan == .pro {
                                Text("Most popular")
                                    .font(.mono(9.5, medium: true))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(SX.accentGradient))
                                    .foregroundColor(SX.C.onAccent)
                            }
                        }
                        Text(plan.tagline.loc)
                            .font(.ui(12.5))
                            .foregroundColor(SX.C.body)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                priceLine(plan)
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(plan.highlights, id: \.self) { h in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(plan == .free ? SX.C.muted : SX.C.ok)
                            Text(h.loc)
                                .font(.ui(13.5))
                                .foregroundColor(SX.C.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                if isSelected {
                    ctaButton(plan)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sxCard(radius: SX.R.xl)
            .overlay(
                RoundedRectangle(cornerRadius: SX.R.xl, style: .continuous)
                    .strokeBorder(isSelected ? SX.C.accent : Color.clear, lineWidth: 2)
            )
            .shadow(color: isSelected ? SX.C.accent.opacity(0.25) : .clear, radius: 20, x: 0, y: 10)
        }
        .buttonStyle(PressableStyle(scale: 0.98))
    }

    @ViewBuilder
    private func priceLine(_ plan: Plan) -> some View {
        if let p = plan.price {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(yearly ? p.yearly : p.monthly)
                    .font(.display(30, bold: true))
                    .foregroundColor(SX.C.ink)
                Text(yearly ? "per year" : "per month")
                    .font(.ui(13))
                    .foregroundColor(SX.C.muted)
                if plan == .team {
                    Text("· per member")
                        .font(.ui(13))
                        .foregroundColor(SX.C.muted)
                }
            }
        } else {
            Text("€0")
                .font(.display(30, bold: true))
                .foregroundColor(SX.C.ink)
        }
    }

    @ViewBuilder
    private func ctaButton(_ plan: Plan) -> some View {
        if plan == .free {
            Text("Your current plan")
                .font(.ui(14, .semibold, fixed: true))
                .foregroundColor(SX.C.body)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(Capsule().fill(SX.C.glass))
        } else {
            VStack(spacing: 6) {
                Text("Opens with SCYDE accounts")
                    .font(.ui(15, .semibold, fixed: true))
                    .foregroundColor(SX.C.onAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(SX.accentGradient))
                    .opacity(0.6)
                Text("You already have every \(plan.name) feature during the beta.")
                    .font(.ui(11.5))
                    .foregroundColor(SX.C.muted)
            }
        }
    }

    private var comparison: some View {
        VStack(spacing: 0) {
            HStack {
                Text("")
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(Plan.allCases) { p in
                    Text(p.name.loc)
                        .font(.ui(12.5, .semibold, fixed: true))
                        .foregroundColor(p == .pro ? SX.C.accent : SX.C.ink)
                        .frame(width: 72)
                }
            }
            .padding(.vertical, 10)
            ForEach(matrix) { row in
                Divider().overlay(SX.C.line)
                HStack {
                    Text(row.name.loc)
                        .font(.ui(12.5))
                        .foregroundColor(SX.C.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ForEach(row.values.indices, id: \.self) { i in
                        Text(row.values[i].loc)
                            .font(.mono(10.5, medium: true))
                            .foregroundColor(SX.C.ink)
                            .multilineTextAlignment(.center)
                            .frame(width: 72)
                    }
                }
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 14)
        .sxCard(radius: SX.R.l)
    }
}
