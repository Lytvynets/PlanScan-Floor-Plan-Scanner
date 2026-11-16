// Interactive plan: Canvas + FloorPlanDrawer with pinch zoom, pan, double-tap to fit, tap hit-testing, and its glass toolbar.
import SwiftUI

extension PlanHitTester.Hit: Identifiable {
    var id: UUID { elementID }
}

@MainActor
struct InteractivePlanView: View {
    let plan: FloorPlanModel
    let layers: PlanLayers
    let theme: PlanTheme
    let units: UnitSystem
    @Binding var selection: PlanHitTester.Hit?
    let fitToken: Int

    @State private var zoom: CGFloat = 1
    @State private var pan: CGSize = .zero
    @GestureState private var gestureZoom: CGFloat = 1
    @GestureState private var gesturePan: CGSize = .zero

    var body: some View {
        GeometryReader { geo in
            let rect = CGRect(origin: .zero, size: geo.size)
            let layout = PlanLayout.fit(plan, in: CanvasRect(rect), padding: 0.08, includeAnnotations: layers.dimensions)
                .applying(Affine2D(viewTransform(size: geo.size)))
            let style = PlanStyle.theme(theme)
            let formatter = UnitFormatter.localized(units)
            Canvas { context, _ in
                context.withCGContext { cgContext in
                    FloorPlanDrawer.draw(plan, in: cgContext, rect: rect, layout: layout, style: style, layers: layers,
                                         formatter: formatter, selection: selection?.elementID)
                }
            }
            .contentShape(Rectangle())
            .gesture(magnifyGesture.simultaneously(with: dragGesture))
            .onTapGesture(count: 2) {
                withAnimation(Theme.spring) { resetViewport() }
            }
            .onTapGesture { location in
                let hit = PlanHitTester.hitTest(location, plan: plan, layout: layout, includeFurniture: layers.furniture)
                if let hit {
                    Haptics.shared.selection()
                    selection = hit
                } else {
                    selection = nil
                }
            }
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: accessibilitySummary(formatter: formatter)))
            .accessibilityHint(Text("Pinch to zoom, drag to move, double-tap to fit."))
        }
        .onChange(of: fitToken) {
            withAnimation(Theme.spring) { resetViewport() }
        }
        .onChange(of: plan.rotationDegrees) {
            resetViewport()
        }
    }

    private func resetViewport() {
        zoom = 1
        pan = .zero
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat { min(max(value, 0.5), 8) }

    /// Zoom around the view center, then pan.
    private func viewTransform(size: CGSize) -> CGAffineTransform {
        let scale = clampedZoom(zoom * gestureZoom)
        let cx = size.width / 2, cy = size.height / 2
        return CGAffineTransform(translationX: -cx, y: -cy)
            .concatenating(CGAffineTransform(scaleX: scale, y: scale))
            .concatenating(CGAffineTransform(translationX: cx + pan.width + gesturePan.width,
                                             y: cy + pan.height + gesturePan.height))
    }

    private var magnifyGesture: some Gesture {
        MagnifyGesture()
            .updating($gestureZoom) { value, state, _ in
                state = value.magnification
            }
            .onEnded { value in
                zoom = clampedZoom(zoom * value.magnification)
            }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .updating($gesturePan) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                pan.width += value.translation.width
                pan.height += value.translation.height
            }
    }

    private func accessibilitySummary(formatter: UnitFormatter) -> String {
        let metrics = RoomMetrics.total(of: plan.rooms)
        let name = plan.rooms.count == 1 ? (plan.rooms.first?.name ?? "") : String(localized: "Whole floor")
        let area = formatter.area(metrics.floorArea)
        let wallCount = metrics.wallCount
        let doorCount = metrics.doorCount
        let windowCount = metrics.windowCount
        return String(localized: "Floor plan of \(name). Area \(area). Walls: \(wallCount). Doors: \(doorCount). Windows: \(windowCount).")
    }
}

/// Interactive plan plus the floating glass toolbar (layers, theme, units, rotate, fit) and the element sheet.
@MainActor
struct PlanCanvasScreen: View {
    let plan: FloorPlanModel
    var title = ""

    @Environment(AppEnvironment.self) private var env
    @State private var layers = PlanLayers.all
    @State private var rotation: Double = 0
    @State private var selection: PlanHitTester.Hit?
    @State private var fitToken = 0
    @State private var didApplyDefaults = false

    private var displayedPlan: FloorPlanModel {
        var copy = plan
        copy.rotationDegrees = rotation
        return copy
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            InteractivePlanView(plan: displayedPlan, layers: layers, theme: env.settings.planTheme,
                                units: env.settings.unitSystem, selection: $selection, fitToken: fitToken)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(Theme.stroke))
                .padding(.horizontal, 12)
            toolbar
                .padding(.bottom, 16)
        }
        .onAppear {
            guard !didApplyDefaults else { return }
            didApplyDefaults = true
            layers.furniture = env.settings.showFurnitureByDefault
        }
        .sheet(item: $selection) { hit in
            ElementDetailSheet(plan: plan, hit: hit)
                .glassSheet(detents: [.fraction(0.4), .medium])
        }
    }

    private var toolbar: some View {
        FloatingToolbar {
            ToolbarMenuButton(systemImage: "square.3.layers.3d", label: "Layers") {
                Toggle("Dimensions", isOn: $layers.dimensions)
                Toggle("Doors & windows", isOn: $layers.openings)
                Toggle("Furniture", isOn: $layers.furniture)
                Toggle("Grid", isOn: $layers.grid)
                Toggle("Labels", isOn: $layers.labels)
            }
            ToolbarIconButton(systemImage: env.settings.planTheme == .blueprint ? "moon.stars.fill" : "sun.max.fill",
                              label: "Theme") {
                env.settings.planTheme = env.settings.planTheme == .blueprint ? .paper : .blueprint
            }
            Button {
                Haptics.shared.selection()
                env.settings.unitPreference = env.settings.unitSystem == .metric ? .imperial : .metric
            } label: {
                Text(verbatim: env.settings.unitSystem == .metric ? env.formatter.symbols.meter : env.formatter.symbols.foot)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 42, height: 42)
                    .contentShape(Circle())
            }
            .buttonStyle(PressableButtonStyle(pressedScale: 0.9))
            .accessibilityLabel(Text("Units"))
            ToolbarIconButton(systemImage: "rotate.right", label: "Rotate 90°") {
                withAnimation(Theme.spring) { rotation = (rotation + 90).truncatingRemainder(dividingBy: 360) }
            }
            ToolbarIconButton(systemImage: "arrow.up.left.and.arrow.down.right", label: "Fit") {
                fitToken += 1
            }
        }
    }
}
