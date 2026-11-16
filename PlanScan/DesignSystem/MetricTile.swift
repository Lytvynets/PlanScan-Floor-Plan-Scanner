// Compact glass tile showing one measurement with an icon and a numeric-text transition.
import SwiftUI

@MainActor
struct MetricTile: View {
    private let title: Text
    private let value: String
    private let systemImage: String
    private let tint: Color

    init(_ titleKey: LocalizedStringKey, value: String, systemImage: String, tint: Color = Theme.cyan) {
        self.title = Text(titleKey)
        self.value = value
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            Text(verbatim: value)
                .font(.expanded(.title3, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.55)
            title
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCardBackground(cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }
}
