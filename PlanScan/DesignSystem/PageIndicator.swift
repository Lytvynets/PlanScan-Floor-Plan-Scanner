// Animated page indicator: the active page is a wide gradient capsule.
import SwiftUI

@MainActor
struct PageIndicator: View {
    let count: Int
    let index: Int

    var body: some View {
        let pageNumber = index + 1
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { page in
                Capsule()
                    .fill(page == index ? AnyShapeStyle(Theme.horizontalAccent) : AnyShapeStyle(Color.white.opacity(0.22)))
                    .frame(width: page == index ? 28 : 8, height: 8)
            }
        }
        .animation(Theme.spring, value: index)
        .accessibilityElement()
        .accessibilityLabel(Text("Page \(pageNumber) of \(count)"))
    }
}
