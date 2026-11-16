// "Details" tab: metric tiles and tables of walls, openings and objects.
import SwiftUI

@MainActor
struct RoomDetailsTab: View {
    let geometry: RoomGeometry
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let formatter = env.formatter
        let metrics = RoomMetrics(room: geometry)
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    MetricTile("Floor area", value: formatter.area(metrics.floorArea), systemImage: "square.dashed", tint: Theme.cyan)
                    MetricTile("Perimeter", value: formatter.length(metrics.perimeter), systemImage: "ruler", tint: Theme.blue)
                    MetricTile("Ceiling height", value: formatter.length(metrics.ceilingHeight), systemImage: "arrow.up.and.down", tint: Theme.mint)
                    MetricTile("Volume", value: formatter.volume(metrics.volume), systemImage: "cube", tint: Theme.amber)
                    MetricTile("Net wall area", value: formatter.area(metrics.netWallArea), systemImage: "rectangle.split.3x1", tint: Theme.cyan)
                    MetricTile("Doors", value: "\(metrics.doorCount)", systemImage: "door.left.hand.open", tint: Theme.mint)
                    MetricTile("Windows", value: "\(metrics.windowCount)", systemImage: "window.vertical.closed", tint: Theme.blue)
                }

                SectionHeader("Walls")
                table(headers: ["#", String(localized: "Length"), String(localized: "Height"), String(localized: "Area")],
                      rows: geometry.walls.enumerated().map { index, wall in
                          ["\(index + 1)", formatter.length(wall.length), formatter.length(wall.height),
                           formatter.area(wall.length * wall.height)]
                      })

                if !geometry.openings.isEmpty {
                    SectionHeader("Doors & windows")
                    table(headers: [String(localized: "Type"), String(localized: "Width"), String(localized: "Height"), String(localized: "Sill")],
                          rows: geometry.openings.map { opening in
                              [opening.kind.displayName, formatter.length(opening.width), formatter.length(opening.height),
                               opening.kind == .window ? formatter.length(opening.sillHeight) : "—"]
                          })
                }

                if !geometry.objects.isEmpty {
                    SectionHeader("Objects")
                    table(headers: [String(localized: "Object"), String(localized: "W × D × H")],
                          rows: geometry.objects.map { item in
                              [item.category.displayName,
                               "\(formatter.length(item.width)) × \(formatter.length(item.depth)) × \(formatter.length(item.height))"]
                          })
                }
            }
            .padding(.horizontal, Theme.margin)
            .padding(.vertical, 12)
        }
    }

    private func table(headers: [String], rows: [[String]]) -> some View {
        VStack(spacing: 0) {
            HStack {
                ForEach(Array(headers.enumerated()), id: \.offset) { index, header in
                    Text(verbatim: header)
                        .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : .trailing)
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.textSecondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.05))
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                HStack {
                    ForEach(Array(row.enumerated()), id: \.offset) { index, cell in
                        Text(verbatim: cell)
                            .frame(maxWidth: .infinity, alignment: index == 0 ? .leading : .trailing)
                    }
                }
                .font(.footnote.monospacedDigit())
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                if rowIndex < rows.count - 1 {
                    Divider().overlay(Theme.stroke)
                }
            }
        }
        .glassCardBackground(cornerRadius: 16)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
