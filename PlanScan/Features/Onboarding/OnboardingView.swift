// Four onboarding pages with live animated demos, a custom page indicator and the "I'm a…" role picker.
import SwiftUI

enum OnboardingPage: Int, CaseIterable, Identifiable {
    case scan, plan, explore, export
    var id: Int { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .scan: "Scan a room in about a minute"
        case .plan: "Get a precise floor plan"
        case .explore: "Explore in 3D and AR"
        case .export: "Export, share, estimate"
        }
    }

    var subtitle: LocalizedStringKey {
        switch self {
        case .scan: "Walk around with your LiDAR iPhone. PlanScan measures walls, doors, windows and furniture for you."
        case .plan: "Wall lengths, openings and the room area — in meters or feet, ready for your renovation."
        case .explore: "Turn every scan into a dollhouse model and place it in your space with AR."
        case .export: "True-scale PDF, PNG, DXF for CAD and USDZ — plus paint, flooring and tile calculators."
        }
    }
}

@MainActor
struct OnboardingView: View {
    let onFinished: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var page = 0
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 32
    @ScaledMetric(relativeTo: .body) private var subtitleSize: CGFloat = 17

    private var isLastPage: Bool { page == OnboardingPage.allCases.count - 1 }

    var body: some View {
        ZStack {
            DotFieldBackground(intensity: 0.3, pulsePeriod: 6)
            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(OnboardingPage.allCases) { item in
                        pageView(item)
                            .tag(item.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .sensoryFeedback(.selection, trigger: page) { _, _ in env.settings.hapticsEnabled }

                VStack(spacing: 18) {
                    PageIndicator(count: OnboardingPage.allCases.count, index: page)
                    PrimaryButton(isLastPage ? "Start" : "Continue", systemImage: isLastPage ? "arrow.right" : nil) {
                        advance()
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.top, 8)
                .padding(.bottom, 16)
            }
        }
    }

    private func advance() {
        if isLastPage {
            env.settings.hasCompletedOnboarding = true
            onFinished()
        } else {
            withAnimation(Theme.spring) { page += 1 }
        }
    }

    private func pageView(_ item: OnboardingPage) -> some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                demo(for: item, isActive: page == item.rawValue)
                    .frame(height: geo.size.height * 0.55)
                    .frame(maxWidth: .infinity)
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(item.title)
                            .font(.system(size: titleSize, weight: .bold).width(.expanded))
                            .foregroundStyle(Theme.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(item.subtitle)
                            .font(.system(size: subtitleSize))
                            .foregroundStyle(Theme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if item == .export {
                            rolePicker
                                .padding(.top, 6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.margin)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
    }

    @ViewBuilder
    private func demo(for item: OnboardingPage, isActive: Bool) -> some View {
        switch item {
        case .scan: ScanDemoView(isActive: isActive)
        case .plan: PlanDemoView(isActive: isActive)
        case .explore: ThreeDDemoView(isActive: isActive)
        case .export: ExportDemoView(isActive: isActive)
        }
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("I'm a…")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], alignment: .leading, spacing: 10) {
                ForEach(UserRole.allCases) { role in
                    Chip(verbatim: role.displayName, systemImage: role.systemImage,
                         isSelected: env.settings.userRole == role) {
                        withAnimation(Theme.quickSpring) {
                            env.settings.userRole = env.settings.userRole == role ? nil : role
                        }
                    }
                }
            }
        }
    }
}
