// Vector plan thumbnail drawn by the shared FloorPlanDrawer (cards, previews).
import SwiftUI

@MainActor
struct PlanThumbnail: View {
    let plan: FloorPlanModel?
    var showsFurniture = false
    var theme: PlanTheme = .blueprint
    var showsBackground = true

    var body: some View {
        Canvas { context, size in
            guard let plan, !plan.isEmpty else { return }
            let style = theme == .blueprint ? PlanStyle.blueprint.transparent() : PlanStyle.paper.transparent()
            context.withCGContext { cgContext in
                FloorPlanDrawer.draw(plan, in: cgContext, rect: CGRect(origin: .zero, size: size), style: style,
                                     layers: showsFurniture ? .thumbnailWithFurniture : .thumbnail, units: .metric)
            }
        }
        .overlay {
            if plan == nil || plan?.isEmpty == true {
                Image(systemName: "square.dashed")
                    .font(.title)
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .background {
            if showsBackground {
                theme == .blueprint ? Color(hex: 0x0A1A33) : Color.white
            }
        }
        .accessibilityHidden(true)
    }
}

/// Room thumbnail: the stored thumb.png when available, otherwise the vector thumbnail.
@MainActor
struct RoomThumbnail: View {
    let imageURL: URL?
    let plan: FloorPlanModel?

    var body: some View {
        if let imageURL, let image = UIImage(contentsOfFile: imageURL.path) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding(8)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(hex: 0x0A1A33))
                .accessibilityHidden(true)
        } else {
            PlanThumbnail(plan: plan)
        }
    }
}
