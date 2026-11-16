// Bottom sheet with details of a tapped wall (length, height, area, openings) or object (category, W × D × H).
import SwiftUI

@MainActor
struct ElementDetailSheet: View {
    let plan: FloorPlanModel
    let hit: PlanHitTester.Hit

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch hit {
                    case .wall(let roomIndex, let wallID):
                        if let room = plan.rooms[safe: roomIndex], let wall = room.walls.first(where: { $0.id == wallID }) {
                            wallDetails(wall, in: room)
                        }
                    case .object(let roomIndex, let objectID):
                        if let room = plan.rooms[safe: roomIndex], let item = room.objects.first(where: { $0.id == objectID }) {
                            objectDetails(item)
                        }
                    }
                }
                .padding(Theme.margin)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func wallDetails(_ wall: Wall, in room: RoomGeometry) -> some View {
        let formatter = env.formatter
        let openings = room.openings(on: wall)
        return VStack(alignment: .leading, spacing: 14) {
            Label("Wall", systemImage: "rectangle.portrait.fill")
                .font(.expanded(.title3, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                MetricTile("Length", value: formatter.length(wall.length), systemImage: "ruler", tint: Theme.cyan)
                MetricTile("Height", value: formatter.length(wall.height), systemImage: "arrow.up.and.down", tint: Theme.blue)
                MetricTile("Area", value: formatter.area(wall.length * wall.height), systemImage: "square.fill", tint: Theme.mint)
                MetricTile("Confidence", value: wall.confidence.confidenceName, systemImage: "checkmark.seal", tint: Theme.amber)
            }
            if !openings.isEmpty {
                SectionHeader("Openings on this wall")
                ForEach(openings) { opening in
                    HStack {
                        Image(systemName: opening.kind.systemImage)
                            .foregroundStyle(Theme.mint)
                        Text(verbatim: opening.kind.displayName)
                        Spacer()
                        Text(verbatim: "\(formatter.length(opening.width)) × \(formatter.length(opening.height))")
                            .monospacedDigit()
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .font(.subheadline)
                    .padding(12)
                    .glassCardBackground(cornerRadius: 14)
                }
            }
        }
    }

    private func objectDetails(_ item: FurnitureItem) -> some View {
        let formatter = env.formatter
        return VStack(alignment: .leading, spacing: 14) {
            Label {
                Text(verbatim: item.category.displayName)
            } icon: {
                Image(systemName: item.category.symbolName)
            }
            .font(.expanded(.title3, weight: .bold))
            .foregroundStyle(Theme.textPrimary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                MetricTile("Width", value: formatter.length(item.width), systemImage: "arrow.left.and.right", tint: Theme.cyan)
                MetricTile("Depth", value: formatter.length(item.depth), systemImage: "arrow.up.left.and.arrow.down.right", tint: Theme.blue)
                MetricTile("Height", value: formatter.length(item.height), systemImage: "arrow.up.and.down", tint: Theme.mint)
                MetricTile("Footprint", value: formatter.area(item.width * item.depth), systemImage: "square.dashed", tint: Theme.amber)
            }
        }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
