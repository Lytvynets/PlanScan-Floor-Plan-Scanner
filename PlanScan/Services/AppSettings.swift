// User settings and app flags persisted in UserDefaults (units, theme, paper, onboarding, paywall cooldown).
import Foundation
import Observation

enum UnitPreference: String, CaseIterable, Identifiable {
    case auto, metric, imperial
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: String(localized: "Automatic")
        case .metric: String(localized: "Metric (m)")
        case .imperial: String(localized: "Imperial (ft)")
        }
    }
}

enum PlanTheme: String, CaseIterable, Identifiable, Codable {
    case blueprint, paper
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .blueprint: String(localized: "Blueprint")
        case .paper: String(localized: "Paper")
        }
    }
}

enum PaperSize: String, CaseIterable, Identifiable, Codable {
    case a4, letter
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .a4: "A4"
        case .letter: "Letter"
        }
    }

    /// Page size in PDF points.
    var pointSize: CGSize {
        switch self {
        case .a4: CGSize(width: 595.28, height: 841.89)
        case .letter: CGSize(width: 612, height: 792)
        }
    }

    /// Letter in North America and a few other regions, A4 elsewhere.
    static var regionDefault: PaperSize {
        let letterRegions: Set<String> = ["US", "CA", "MX", "PH", "CL", "CO", "VE", "GT", "CR", "PA", "SV", "DO", "PR"]
        return letterRegions.contains(Locale.current.region?.identifier ?? "") ? .letter : .a4
    }
}

enum UserRole: String, CaseIterable, Identifiable, Codable {
    case homeowner, realtor, designer, contractor
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .homeowner: String(localized: "Homeowner")
        case .realtor: String(localized: "Realtor")
        case .designer: String(localized: "Designer")
        case .contractor: String(localized: "Contractor")
        }
    }

    var systemImage: String {
        switch self {
        case .homeowner: "house.fill"
        case .realtor: "key.fill"
        case .designer: "paintpalette.fill"
        case .contractor: "hammer.fill"
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var unitPreference: UnitPreference { didSet { defaults.set(unitPreference.rawValue, forKey: Keys.units) } }
    var planTheme: PlanTheme { didSet { defaults.set(planTheme.rawValue, forKey: Keys.theme) } }
    var paperSize: PaperSize { didSet { defaults.set(paperSize.rawValue, forKey: Keys.paper) } }
    var companyName: String { didSet { defaults.set(companyName, forKey: Keys.company) } }
    var showFurnitureByDefault: Bool { didSet { defaults.set(showFurnitureByDefault, forKey: Keys.furniture) } }
    var hapticsEnabled: Bool {
        didSet {
            defaults.set(hapticsEnabled, forKey: Keys.haptics)
            Haptics.shared.isEnabled = hapticsEnabled
        }
    }
    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }
    var userRole: UserRole? { didSet { defaults.set(userRole?.rawValue, forKey: Keys.role) } }
    var lastPaywallShownAt: Date? { didSet { defaults.set(lastPaywallShownAt, forKey: Keys.paywallShown) } }
    var hasSeenScanTips: Bool { didSet { defaults.set(hasSeenScanTips, forKey: Keys.scanTips) } }
    var hasSavedFirstRoom: Bool { didSet { defaults.set(hasSavedFirstRoom, forKey: Keys.firstRoom) } }
    var sampleSeeded: Bool { didSet { defaults.set(sampleSeeded, forKey: Keys.sampleSeeded) } }
    var debugProOverride: Bool { didSet { defaults.set(debugProOverride, forKey: Keys.debugPro) } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        unitPreference = UnitPreference(rawValue: defaults.string(forKey: Keys.units) ?? "") ?? .auto
        planTheme = PlanTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .blueprint
        paperSize = PaperSize(rawValue: defaults.string(forKey: Keys.paper) ?? "") ?? PaperSize.regionDefault
        companyName = defaults.string(forKey: Keys.company) ?? ""
        showFurnitureByDefault = defaults.object(forKey: Keys.furniture) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        userRole = UserRole(rawValue: defaults.string(forKey: Keys.role) ?? "")
        lastPaywallShownAt = defaults.object(forKey: Keys.paywallShown) as? Date
        hasSeenScanTips = defaults.bool(forKey: Keys.scanTips)
        hasSavedFirstRoom = defaults.bool(forKey: Keys.firstRoom)
        sampleSeeded = defaults.bool(forKey: Keys.sampleSeeded)
        debugProOverride = defaults.bool(forKey: Keys.debugPro)
        Haptics.shared.isEnabled = hapticsEnabled
    }

    /// Units actually used: the explicit choice, or the device locale's measurement system.
    var unitSystem: UnitSystem {
        switch unitPreference {
        case .metric: return .metric
        case .imperial: return .imperial
        case .auto: return Locale.current.measurementSystem == .us ? .imperial : .metric
        }
    }

    var formatter: UnitFormatter { UnitFormatter.localized(unitSystem) }

    /// The launch paywall is due for Free users when it has not been shown in the last 24 hours.
    var isLaunchPaywallDue: Bool {
        guard let last = lastPaywallShownAt else { return true }
        return Date().timeIntervalSince(last) > AppConfig.paywallCooldown
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        userRole = nil
        lastPaywallShownAt = nil
        hasSeenScanTips = false
    }

    private enum Keys {
        static let units = "settings.units"
        static let theme = "settings.planTheme"
        static let paper = "settings.paperSize"
        static let company = "settings.companyName"
        static let furniture = "settings.showFurniture"
        static let haptics = "settings.haptics"
        static let onboarding = "flags.hasCompletedOnboarding"
        static let role = "flags.userRole"
        static let paywallShown = "flags.lastPaywallShownAt"
        static let scanTips = "flags.hasSeenScanTips"
        static let firstRoom = "flags.hasSavedFirstRoom"
        static let sampleSeeded = "flags.sampleSeeded"
        static let debugPro = "debug.proOverride"
    }
}
