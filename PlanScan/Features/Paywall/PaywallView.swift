// Subscription paywall: role-personalized headline, benefits, StoreKit plan cards, purchase/restore and legal links.
import StoreKit
import SwiftUI

@MainActor
struct PaywallView: View {
    let reason: PaywallReason
    let onClose: () -> Void

    @Environment(AppEnvironment.self) private var env
    @State private var selectedProductID = AppConfig.yearlyProductID
    @State private var showClose = false
    @State private var revealBenefits = false
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?
    @State private var closeAfterInfo = false
    @State private var celebration = 0
    @State private var didComplete = false

    private var store: StoreManager { env.store }
    private var selectedProduct: Product? { store.products.first { $0.id == selectedProductID } }

    var body: some View {
        ZStack(alignment: .topLeading) {
            DotFieldBackground(intensity: 0.25, pulsePeriod: 7)
            ScrollView {
                VStack(spacing: 22) {
                    PaywallHero()
                        .padding(.top, 52)
                    header
                    benefits
                    plans
                    purchaseSection
                    footer
                }
                .padding(.horizontal, Theme.margin)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)

            GlassIconButton(systemImage: "xmark", accessibilityLabel: "Close") { close() }
                .padding(.leading, 16)
                .padding(.top, 8)
                .opacity(showClose ? 1 : 0)
                .disabled(!showClose)
                .animation(.easeInOut(duration: 0.6), value: showClose)

            if isPurchasing {
                purchaseOverlay
            }
            ParticleBurst(trigger: celebration, fireOnAppear: false)
                .ignoresSafeArea()
        }
        .background(Theme.background.ignoresSafeArea())
        .task {
            revealBenefits = true
            if store.loadState != .loaded { await store.loadProducts() }
        }
        .task {
            try? await Task.sleep(for: .seconds(AppConfig.paywallCloseDelay))
            showClose = true
        }
        .onChange(of: store.isPro) { _, isPro in
            if isPro && !isPurchasing && !didComplete { finishWithSuccess(celebrate: false) }
        }
        .alert(Text("Purchase failed"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
        .alert(Text("PlanScan Pro"), isPresented: Binding(get: { infoMessage != nil }, set: { if !$0 { infoMessage = nil } })) {
            Button("OK", role: .cancel) {
                if closeAfterInfo { close() }
            }
        } message: {
            Text(verbatim: infoMessage ?? "")
        }
    }

    // MARK: Sections

    private var headline: LocalizedStringKey {
        switch env.settings.userRole {
        case .homeowner: "Plan your renovation with real measurements"
        case .realtor: "Listing-ready floor plans in minutes"
        case .designer: "Design layouts on accurate plans"
        case .contractor: "Measure, estimate and quote faster"
        case nil: "Turn any room into a precise floor plan"
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            if let banner = reason.banner {
                Badge(verbatim: banner, systemImage: "lock.fill", tint: Theme.amber)
            }
            Text(headline)
                .font(.expanded(.title, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            Text("Everything in PlanScan, without limits.")
                .font(.callout)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var benefits: some View {
        VStack(alignment: .leading, spacing: 14) {
            BenefitRow(text: "Unlimited rooms & projects", systemImage: "square.stack.3d.up.fill", isVisible: revealBenefits, index: 0)
            BenefitRow(text: "Whole-home plans (merge rooms)", systemImage: "house.fill", isVisible: revealBenefits, index: 1)
            BenefitRow(text: "PDF at true scale & DXF for CAD, no watermark", systemImage: "doc.richtext.fill", isVisible: revealBenefits, index: 2)
            BenefitRow(text: "3D model export & AR", systemImage: "arkit", isVisible: revealBenefits, index: 3)
            BenefitRow(text: "Renovation calculators", systemImage: "function", isVisible: revealBenefits, index: 4)
        }
        .padding(18)
        .glassCardBackground()
    }

    @ViewBuilder
    private var plans: some View {
        switch store.loadState {
        case .idle, .loading:
            VStack(spacing: 12) {
                ShimmerView(cornerRadius: Theme.cornerRadius).frame(height: 96)
                ShimmerView(cornerRadius: Theme.cornerRadius).frame(height: 76)
            }
        case .failed:
            VStack(spacing: 12) {
                PlanOptionCard(title: "Yearly", priceLine: "—", detailLine: nil, isSelected: true, isBestValue: true) {}
                    .disabled(true)
                PlanOptionCard(title: "Monthly", priceLine: "—", detailLine: nil, isSelected: false, isBestValue: false) {}
                    .disabled(true)
                Button {
                    Task { await store.loadProducts() }
                } label: {
                    Label("Retry", systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.semibold))
                }
                .tint(Theme.cyan)
                Text("Subscriptions are not available right now. Check your connection and try again.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        case .loaded:
            VStack(spacing: 12) {
                if let yearly = store.yearly {
                    PlanOptionCard(title: "Yearly",
                                   priceLine: SubscriptionText.priceLine(yearly, eligibleForIntro: store.isEligibleForIntroOffer(yearly)),
                                   detailLine: SubscriptionText.weeklyPrice(yearly),
                                   isSelected: selectedProductID == yearly.id, isBestValue: true) {
                        selectedProductID = yearly.id
                    }
                }
                if let monthly = store.monthly {
                    PlanOptionCard(title: "Monthly",
                                   priceLine: SubscriptionText.priceLine(monthly, eligibleForIntro: store.isEligibleForIntroOffer(monthly)),
                                   detailLine: nil,
                                   isSelected: selectedProductID == monthly.id, isBestValue: false) {
                        selectedProductID = monthly.id
                    }
                }
            }
        }
    }

    private var ctaIsTrial: Bool {
        guard let product = selectedProduct else { return false }
        return SubscriptionText.hasFreeTrial(product) && store.isEligibleForIntroOffer(product)
    }

    private var purchaseSection: some View {
        VStack(spacing: 12) {
            PrimaryButton(ctaIsTrial ? "Start free trial" : "Continue", isLoading: isPurchasing,
                          isEnabled: selectedProduct != nil && store.loadState == .loaded) {
                purchase()
            }
            Text("Cancel anytime in Settings")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Payment is charged to your Apple Account at confirmation of purchase. The subscription renews automatically unless it is canceled at least 24 hours before the end of the current period; your account is charged for renewal within 24 hours before the period ends. Manage or cancel your subscription in your App Store account settings.")
                .font(.caption2)
                .foregroundStyle(Theme.textTertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack(spacing: 18) {
            Button("Restore") { restore() }
            Text(verbatim: "·").foregroundStyle(Theme.textTertiary)
            Link("Terms", destination: AppConfig.termsURL)
            Text(verbatim: "·").foregroundStyle(Theme.textTertiary)
            Link("Privacy", destination: AppConfig.privacyURL)
        }
        .font(.footnote.weight(.semibold))
        .tint(Theme.textSecondary)
        .foregroundStyle(Theme.textSecondary)
    }

    private var purchaseOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
                Text("Contacting the App Store…")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.white)
            }
            .padding(28)
            .glassCardBackground()
        }
        .transition(.opacity)
    }

    // MARK: Actions

    private func purchase() {
        guard let product = selectedProduct, !isPurchasing else { return }
        isPurchasing = true
        Task {
            do {
                let outcome = try await store.purchase(product)
                isPurchasing = false
                switch outcome {
                case .success:
                    finishWithSuccess(celebrate: true)
                case .pending:
                    infoMessage = String(localized: "Your purchase is waiting for approval. Pro unlocks as soon as it is approved.")
                case .cancelled:
                    break
                }
            } catch {
                isPurchasing = false
                Haptics.shared.error()
                errorMessage = error.localizedDescription
            }
        }
    }

    private func restore() {
        guard !isPurchasing else { return }
        isPurchasing = true
        Task {
            do {
                let active = try await store.restore()
                isPurchasing = false
                if active {
                    didComplete = true
                    Haptics.shared.success()
                    closeAfterInfo = true
                    infoMessage = String(localized: "Your Pro subscription has been restored.")
                } else {
                    infoMessage = String(localized: "No active subscription was found for this Apple Account.")
                }
            } catch {
                isPurchasing = false
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finishWithSuccess(celebrate: Bool) {
        guard !didComplete else { return }
        didComplete = true
        Haptics.shared.success()
        if celebrate {
            celebration += 1
            Task {
                try? await Task.sleep(for: .seconds(1.3))
                onClose()
            }
        } else {
            onClose()
        }
    }

    private func close() {
        Haptics.shared.light()
        onClose()
    }
}

extension View {
    /// Presents the paywall full-screen for a Pro feature or the Free room limit.
    func paywallCover(_ reason: Binding<PaywallReason?>) -> some View {
        fullScreenCover(item: reason) { item in
            PaywallPresentation(reason: item)
        }
    }
}

/// Wraps the paywall for modal presentation (dismisses itself when closed).
@MainActor
private struct PaywallPresentation: View {
    let reason: PaywallReason
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PaywallView(reason: reason) { dismiss() }
    }
}
