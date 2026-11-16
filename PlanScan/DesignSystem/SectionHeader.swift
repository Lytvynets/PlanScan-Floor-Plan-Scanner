// Section header with an optional subtitle and trailing action, plus iOS 18 zoom-transition helpers.
import SwiftUI

@MainActor
struct SectionHeader: View {
    private let title: Text
    private let subtitle: Text?
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    init(_ title: LocalizedStringKey, subtitle: LocalizedStringKey? = nil,
         actionTitle: LocalizedStringKey? = nil, action: (() -> Void)? = nil) {
        self.title = Text(title)
        self.subtitle = subtitle.map { Text($0) }
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                title
                    .font(.expanded(.headline, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    subtitle
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            Spacer(minLength: 8)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.cyan)
            }
        }
    }
}

extension View {
    /// Marks a view as the source of an iOS 18 zoom navigation transition (no-op on iOS 17).
    @ViewBuilder
    func zoomTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.matchedTransitionSource(id: id, in: namespace) // ios18-api
        } else {
            self
        }
    }

    /// Uses the iOS 18 zoom navigation transition for a pushed destination (plain push on iOS 17).
    @ViewBuilder
    func zoomTransitionDestination(id: some Hashable, in namespace: Namespace.ID) -> some View {
        if #available(iOS 18.0, *) {
            self.navigationTransition(.zoom(sourceID: id, in: namespace)) // ios18-api
        } else {
            self
        }
    }
}
