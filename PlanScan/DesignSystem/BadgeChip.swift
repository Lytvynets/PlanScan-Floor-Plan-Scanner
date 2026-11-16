// Small tinted badges and selectable chips.
import SwiftUI

@MainActor
struct Badge: View {
    private let label: Text
    private let systemImage: String?
    private let tint: Color

    init(_ titleKey: LocalizedStringKey, systemImage: String? = nil, tint: Color = Theme.cyan) {
        self.label = Text(titleKey)
        self.systemImage = systemImage
        self.tint = tint
    }

    init(verbatim title: String, systemImage: String? = nil, tint: Color = Theme.cyan) {
        self.label = Text(verbatim: title)
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            label
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .lineLimit(1)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(tint.opacity(0.32), lineWidth: 1))
    }
}

@MainActor
struct Chip: View {
    private let label: Text
    private let systemImage: String?
    private let isSelected: Bool
    private let action: (() -> Void)?

    init(_ titleKey: LocalizedStringKey, systemImage: String? = nil, isSelected: Bool = false, action: (() -> Void)? = nil) {
        self.label = Text(titleKey)
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    init(verbatim title: String, systemImage: String? = nil, isSelected: Bool = false, action: (() -> Void)? = nil) {
        self.label = Text(verbatim: title)
        self.systemImage = systemImage
        self.isSelected = isSelected
        self.action = action
    }

    private var content: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage)
            }
            label
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isSelected ? Color.white : Theme.textSecondary)
        .lineLimit(1)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background {
            Capsule().fill(isSelected ? AnyShapeStyle(Theme.accentGradient.opacity(0.85)) : AnyShapeStyle(.ultraThinMaterial))
        }
        .overlay(Capsule().strokeBorder(isSelected ? Color.white.opacity(0.25) : Theme.stroke, lineWidth: 1))
        .contentShape(Capsule())
    }

    var body: some View {
        if let action {
            Button {
                Haptics.shared.selection()
                action()
            } label: {
                content
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.95))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            content
        }
    }
}
