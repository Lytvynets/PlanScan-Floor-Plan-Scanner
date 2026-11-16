// StoreKit 2: product loading, transaction listener, entitlements (Pro), purchase, restore and intro-offer eligibility.
import Foundation
import Observation
import StoreKit

@Observable
@MainActor
final class StoreManager {
    enum LoadState: Equatable {
        case idle, loading, loaded, failed
    }

    enum PurchaseOutcome {
        case success, cancelled, pending
    }

    enum StoreError: LocalizedError {
        case failedVerification
        case productsUnavailable

        var errorDescription: String? {
            switch self {
            case .failedVerification: String(localized: "The App Store could not verify this purchase.")
            case .productsUnavailable: String(localized: "Subscriptions are not available right now. Check your connection and try again.")
            }
        }
    }

    private(set) var products: [Product] = []
    private(set) var loadState: LoadState = .idle
    private(set) var purchasedProductIDs: Set<String> = []
    private(set) var introOfferEligibility: [String: Bool] = [:]
    private(set) var entitlementsChecked = false
    /// Debug-only override (Settings → Debug).
    var debugProOverride = false

    @ObservationIgnored private var updatesTask: Task<Void, Never>?

    var isPro: Bool { debugProOverride || !purchasedProductIDs.isEmpty }

    var yearly: Product? { products.first { $0.id == AppConfig.yearlyProductID } }
    var monthly: Product? { products.first { $0.id == AppConfig.monthlyProductID } }

    /// Starts listening for transactions and loads products + entitlements (called during the splash).
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task.detached(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(transactionResult: result)
            }
        }
        Task {
            await refreshEntitlements()
            await loadProducts()
        }
    }

    func loadProducts() async {
        if loadState == .loading { return }
        loadState = .loading
        do {
            let loaded = try await Product.products(for: AppConfig.productIDs)
            products = loaded.sorted { lhs, rhs in
                (AppConfig.productIDs.firstIndex(of: lhs.id) ?? 0) < (AppConfig.productIDs.firstIndex(of: rhs.id) ?? 0)
            }
            if products.isEmpty {
                loadState = .failed
                return
            }
            var eligibility: [String: Bool] = [:]
            for product in products {
                if let subscription = product.subscription {
                    eligibility[product.id] = await subscription.isEligibleForIntroOffer
                }
            }
            introOfferEligibility = eligibility
            loadState = .loaded
        } catch {
            loadState = .failed
        }
    }

    func refreshEntitlements() async {
        var active: Set<String> = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.revocationDate == nil,
               transaction.productType == .autoRenewable,
               AppConfig.productIDs.contains(transaction.productID) {
                if let expiration = transaction.expirationDate, expiration < Date() { continue }
                active.insert(transaction.productID)
            }
        }
        purchasedProductIDs = active
        entitlementsChecked = true
    }

    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await refreshEntitlements()
            return .success
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .cancelled
        }
    }

    /// Syncs with the App Store and returns whether Pro is active afterwards.
    func restore() async throws -> Bool {
        try await AppStore.sync()
        await refreshEntitlements()
        return isPro
    }

    func isEligibleForIntroOffer(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer != nil && (introOfferEligibility[product.id] ?? false)
    }

    private func handle(transactionResult result: VerificationResult<Transaction>) async {
        if case .verified(let transaction) = result {
            await transaction.finish()
        }
        await refreshEntitlements()
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value): return value
        case .unverified: throw StoreError.failedVerification
        }
    }
}
