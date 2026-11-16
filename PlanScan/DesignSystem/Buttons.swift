// Primary (gradient) and secondary (glass) buttons with press-scale feedback and haptics.
import SwiftUI

struct PressableButtonStyle: ButtonStyle {
    var pressedScale: CGFloat = 0.97

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressedScale : 1)
            .brightness(configuration.isPressed ? -0.04 : 0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

@MainActor
struct PrimaryButton: View {
    private let title: Text
    private let systemImage: String?
    private let isLoading: Bool
    private let isEnabled: Bool
    private let action: () -> Void

    init(_ titleKey: LocalizedStringKey, systemImage: String? = nil, isLoading: Bool = false,
         isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = Text(titleKey)
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    init(verbatim title: String, systemImage: String? = nil, isLoading: Bool = false,
         isEnabled: Bool = true, action: @escaping () -> Void) {
        self.title = Text(verbatim: title)
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.isEnabled = isEnabled
        self.action = action
    }

    var body: some View {
        Button {
            guard isEnabled, !isLoading else { return }
            Haptics.shared.light()
            action()
        } label: {
            HStack(spacing: 10) {
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    if let systemImage {
                        Image(systemName: systemImage)
                    }
                    title
                }
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(Color.white)
            .shadow(color: .black.opacity(0.25), radius: 2, x: 0, y: 1)
            .frame(maxWidth: .infinity, minHeight: 56)
            .padding(.horizontal, 16)
            .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
            .shadow(color: Theme.cyan.opacity(isEnabled ? 0.32 : 0), radius: 16, x: 0, y: 8)
            .opacity(isEnabled ? 1 : 0.45)
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isEnabled || isLoading)
    }
}

@MainActor
struct SecondaryButton: View {
    private let title: Text
    private let systemImage: String?
    private let tint: Color
    private let action: () -> Void

    init(_ titleKey: LocalizedStringKey, systemImage: String? = nil, tint: Color = .white, action: @escaping () -> Void) {
        self.title = Text(titleKey)
        self.systemImage = systemImage
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button {
            Haptics.shared.light()
            action()
        } label: {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                title
            }
            .font(.headline.weight(.semibold))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

/// Round glass icon button used on overlays (close, reset camera…).
@MainActor
struct GlassIconButton: View {
    let systemImage: String
    let accessibilityLabel: LocalizedStringKey
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.light()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: size, height: size)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(Circle().strokeBorder(Theme.stroke, lineWidth: 1))
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.92))
        .accessibilityLabel(Text(accessibilityLabel))
    }
}
