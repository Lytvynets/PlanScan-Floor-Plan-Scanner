// Single gate for Free vs. Pro features and the Free room limit; also defines why the paywall was opened.
import Foundation

enum ProFeature: String, CaseIterable, Identifiable {
    case unlimitedRooms, wholeHome, pdfExport, dxfExport, usdzExport, arView, calculators, companyName, cleanPNG
    var id: String { rawValue }
}

/// Why the paywall is shown; drives the optional banner on top of the paywall.
enum PaywallReason: Identifiable, Hashable {
    case onboarding
    case launch
    case feature(ProFeature)
    case roomLimit

    var id: String {
        switch self {
        case .onboarding: "onboarding"
        case .launch: "launch"
        case .feature(let feature): "feature.\(feature.rawValue)"
        case .roomLimit: "roomLimit"
        }
    }

    /// Short context line shown above the headline, if any.
    var banner: String? {
        switch self {
        case .onboarding, .launch: nil
        case .roomLimit: String(localized: "You've used \(AppConfig.freeRoomLimit) free rooms")
        case .feature(let feature):
            switch feature {
            case .unlimitedRooms: String(localized: "You've used \(AppConfig.freeRoomLimit) free rooms")
            case .wholeHome: String(localized: "Whole-home scanning is a Pro feature")
            case .pdfExport: String(localized: "True-scale PDF export is a Pro feature")
            case .dxfExport: String(localized: "DXF export for CAD is a Pro feature")
            case .usdzExport: String(localized: "3D model export is a Pro feature")
            case .arView: String(localized: "AR view is a Pro feature")
            case .calculators: String(localized: "Renovation calculators are a Pro feature")
            case .companyName: String(localized: "Branded PDFs are a Pro feature")
            case .cleanPNG: String(localized: "Images without watermark are a Pro feature")
            }
        }
    }
}

@MainActor
struct FeatureGate {
    let store: StoreManager

    var isPro: Bool { store.isPro }

    func isUnlocked(_ feature: ProFeature) -> Bool {
        switch feature {
        case .unlimitedRooms, .wholeHome, .pdfExport, .dxfExport, .usdzExport, .arView, .calculators, .companyName, .cleanPNG:
            return store.isPro
        }
    }

    /// Free users may keep up to `AppConfig.freeRoomLimit` scanned or manual rooms.
    func canAddRoom(savedRoomCount: Int) -> Bool {
        store.isPro || savedRoomCount < AppConfig.freeRoomLimit
    }

    var freeRoomLimit: Int { AppConfig.freeRoomLimit }
}
