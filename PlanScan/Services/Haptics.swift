// Haptic feedback helpers that respect the user's Haptics setting.
import UIKit

@MainActor
final class Haptics {
    static let shared = Haptics()

    /// Mirrors the Haptics toggle in Settings.
    var isEnabled = true

    private let lightGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let rigidGenerator = UIImpactFeedbackGenerator(style: .rigid)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()

    private init() {}

    func light() {
        guard isEnabled else { return }
        lightGenerator.impactOccurred()
    }

    func medium() {
        guard isEnabled else { return }
        mediumGenerator.impactOccurred()
    }

    func snap() {
        guard isEnabled else { return }
        rigidGenerator.impactOccurred(intensity: 0.8)
    }

    func selection() {
        guard isEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    func success() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.success)
    }

    func warning() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }

    func error() {
        guard isEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }
}
