// App-wide constants: legal links, support e-mail, product IDs, Free plan limits and timings.
import Foundation

enum AppConfig {
    /// Replace these placeholders before release (see README → "Before release").
    static let termsURL = link("https://docs.google.com/document/d/1RLOCWZLREuHWRIQRHQpisHeYUZzybiy4/edit?usp=share_link&ouid=114599015370342281433&rtpof=true&sd=true")
    static let privacyURL = link("https://docs.google.com/document/d/1R45JOGneLHaiNO7IvoZrYJs7hLhM2HH9/edit?usp=share_link&ouid=114599015370342281433&rtpof=true&sd=true")
    static let supportEmail = "vladlytvynets7@gmail.com"

    static let yearlyProductID = "planscan.pro.yearly"
    static let monthlyProductID = "planscan.pro.monthly"
    static let productIDs = [yearlyProductID, monthlyProductID]

    /// Saved rooms (scanned + manual) allowed on the Free plan; the sample project does not count.
    static let freeRoomLimit = 3
    /// The launch paywall is shown again to Free users after this interval.
    static let paywallCooldown: TimeInterval = 24 * 60 * 60
    /// The paywall close button fades in after this delay.
    static let paywallCloseDelay: TimeInterval = 3
    /// Default project for new scans.
    static var defaultProjectName: String { String(localized: "My Home") }

    static var supportMailURL: URL {
        let subject = String(localized: "PlanScan support").addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        return link("mailto:\(supportEmail)?subject=\(subject)")
    }

    static var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    /// Builds a URL from a constant string; constants are known to be valid, the fallback only satisfies the type.
    private static func link(_ string: String) -> URL {
        URL(string: string) ?? URL(fileURLWithPath: "/")
    }
}
