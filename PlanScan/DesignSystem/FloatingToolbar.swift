// Floating glass toolbar (capsule) with icon buttons, used on the plan and 3D screens.
import SwiftUI

@MainActor
struct FloatingToolbar<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 2) {
            content
        }
        .padding(5)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }
}

@MainActor
struct ToolbarIconButton: View {
    let systemImage: String
    let label: LocalizedStringKey
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button {
            Haptics.shared.selection()
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isActive ? Theme.background : Color.white)
                .frame(width: 42, height: 42)
                .background {
                    if isActive {
                        Circle().fill(Theme.accentGradient)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.9))
        .accessibilityLabel(Text(label))
    }
}

/// Toolbar item that opens a menu (layer toggles, theme, units).
@MainActor
struct ToolbarMenuButton<MenuContent: View>: View {
    let systemImage: String
    let label: LocalizedStringKey
    private let menuContent: MenuContent

    init(systemImage: String, label: LocalizedStringKey, @ViewBuilder content: () -> MenuContent) {
        self.systemImage = systemImage
        self.label = label
        self.menuContent = content()
    }

    var body: some View {
        Menu {
            menuContent
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.white)
                .frame(width: 42, height: 42)
                .contentShape(Circle())
        }
        .accessibilityLabel(Text(label))
    }
}
