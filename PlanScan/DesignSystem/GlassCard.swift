// Frosted glass card: ultra-thin material, subtle inner gradient, hairline stroke and soft shadow.
import SwiftUI

@MainActor
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 16
    var cornerRadius: CGFloat = Theme.cornerRadius
    private let content: Content

    init(padding: CGFloat = 16, cornerRadius: CGFloat = Theme.cornerRadius, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCardBackground(cornerRadius: cornerRadius)
    }
}

extension View {
    /// Applies the glass card background to any view.
    func glassCardBackground(cornerRadius: CGFloat = Theme.cornerRadius, highlighted: Bool = false) -> some View {
        background {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            ZStack {
                shape.fill(.ultraThinMaterial)
                shape.fill(LinearGradient(colors: [Color.white.opacity(0.07), Color.white.opacity(0.0)],
                                          startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(highlighted ? AnyShapeStyle(Theme.accentGradient) : AnyShapeStyle(Theme.stroke),
                                   lineWidth: highlighted ? 1.5 : 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 18, x: 0, y: 10)
        }
    }
}
