// Manual room builder: rectangle or L-shape templates, ceiling height, doors/windows on chosen walls, live preview.
import SwiftData
import SwiftUI

@MainActor
struct ManualRoomBuilderView: View {
    let preferredProjectID: UUID?

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.updatedAt, order: .reverse) private var allProjects: [Project]
    @State private var spec = ManualRoomSpec()
    @State private var projectID: UUID?
    @State private var newProjectName = ""
    @State private var didSetup = false
    @State private var errorMessage: String?

    private var projects: [Project] { allProjects.filter { !$0.isSample } }
    private var system: UnitSystem { env.settings.unitSystem }
    private var previewRoom: RoomGeometry {
        var room = ManualRoomFactory.makeRoom(spec)
        if room.name.isEmpty { room.name = spec.type.displayName }
        return room
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ManualRoomPreview(room: previewRoom)
                        .frame(height: 230)
                        .listRowInsets(EdgeInsets())
                }

                Section {
                    TextField("Room name", text: $spec.name, prompt: Text(verbatim: spec.type.displayName))
                    Picker("Room type", selection: $spec.type) {
                        ForEach(RoomType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.systemImage).tag(type)
                        }
                    }
                } header: {
                    Text("Room")
                }

                Section {
                    Picker("Shape", selection: $spec.shape) {
                        Text("Rectangle").tag(ManualShape.rectangle)
                        Text("L-shape").tag(ManualShape.lShape)
                    }
                    .pickerStyle(.segmented)
                    if spec.shape == .rectangle {
                        LengthField(title: "Width", meters: $spec.width, system: system)
                        LengthField(title: "Length", meters: $spec.length, system: system)
                    } else {
                        LengthField(title: "Top side", meters: $spec.lTop, system: system)
                        LengthField(title: "Left side", meters: $spec.lLeft, system: system)
                        LengthField(title: "Bottom side", meters: $spec.lBottom, system: system)
                        LengthField(title: "Right side", meters: $spec.lRight, system: system)
                        Text("The bottom and right sides form the inner corner, so they must be shorter than the top and left sides.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    LengthField(title: "Ceiling height", meters: $spec.ceilingHeight, system: system)
                } header: {
                    Text("Shape & size")
                }

                Section {
                    ForEach($spec.openings) { $opening in
                        openingEditor($opening)
                    }
                    HStack(spacing: 10) {
                        addButton(.door, title: "Add door")
                        addButton(.window, title: "Add window")
                    }
                    .buttonStyle(.borderless)
                } header: {
                    Text("Doors & windows")
                }

                Section {
                    Picker("Project", selection: $projectID) {
                        ForEach(projects) { project in
                            Text(verbatim: project.name).tag(Optional(project.id))
                        }
                        Text("New project").tag(UUID?.none)
                    }
                    if projectID == nil {
                        TextField("Project name", text: $newProjectName)
                    }
                } header: {
                    Text("Project")
                }
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .navigationTitle("Manual room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                }
            }
            .alert(Text("Could not save"), isPresented: Binding(get: { errorMessage != nil },
                                                                set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: errorMessage ?? "")
            }
            .onAppear(perform: setup)
        }
    }

    private func addButton(_ kind: OpeningKind, title: LocalizedStringKey) -> some View {
        Button {
            Haptics.shared.selection()
            let count = ManualRoomFactory.wallCount(for: spec.shape)
            let wallIndex = spec.openings.count % count
            withAnimation {
                spec.openings.append(ManualOpeningSpec(kind: kind, wallIndex: wallIndex,
                                                       width: ManualOpeningSpec.defaultWidth(for: kind)))
            }
        } label: {
            Label(title, systemImage: kind.systemImage)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .tint(Theme.cyan)
    }

    private func openingEditor(_ opening: Binding<ManualOpeningSpec>) -> some View {
        let lengths = ManualRoomFactory.wallLengths(for: spec)
        let formatter = env.formatter
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label {
                    Text(verbatim: opening.wrappedValue.kind.displayName)
                } icon: {
                    Image(systemName: opening.wrappedValue.kind.systemImage)
                }
                .font(.headline)
                Spacer()
                Button(role: .destructive) {
                    let id = opening.wrappedValue.id
                    withAnimation { spec.openings.removeAll { $0.id == id } }
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Remove"))
            }
            Picker("Wall", selection: opening.wallIndex) {
                ForEach(lengths.indices, id: \.self) { index in
                    let wallNumber = index + 1
                    (Text("Wall \(wallNumber)") + Text(verbatim: " · \(formatter.length(lengths[index]))")).tag(index)
                }
            }
            LengthField(title: "Width", meters: opening.width, system: system)
            HStack {
                Text("Position")
                Slider(value: opening.position, in: 0...1)
                    .tint(Theme.cyan)
            }
        }
        .padding(.vertical, 4)
    }

    private func setup() {
        guard !didSetup else { return }
        didSetup = true
        if system == .imperial {
            spec.width = 13 * UnitConversion.metersPerFoot
            spec.length = 11 * UnitConversion.metersPerFoot
            spec.ceilingHeight = 8 * UnitConversion.metersPerFoot
        }
        spec.openings = [ManualOpeningSpec(kind: .door, wallIndex: 2, width: ManualOpeningSpec.defaultWidth(for: .door), position: 0.75),
                         ManualOpeningSpec(kind: .window, wallIndex: 0, width: ManualOpeningSpec.defaultWidth(for: .window))]
        if let preferredProjectID, projects.contains(where: { $0.id == preferredProjectID }) {
            projectID = preferredProjectID
        } else if let first = projects.first(where: { $0.name == AppConfig.defaultProjectName }) ?? projects.first {
            projectID = first.id
        } else {
            projectID = nil
            newProjectName = AppConfig.defaultProjectName
        }
    }

    private func save() {
        var room = ManualRoomFactory.makeRoom(spec)
        if room.name.isEmpty { room.name = spec.type.displayName }
        let project: Project
        if let projectID, let existing = projects.first(where: { $0.id == projectID }) {
            project = existing
        } else {
            project = env.projects.createProject(named: newProjectName)
        }
        do {
            let record = try env.projects.saveRoom(room, in: project)
            Haptics.shared.success()
            let projectID = project.id
            dismiss()
            env.didSaveRoom(record.id, projectID: projectID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Unit-aware numeric field that stores meters.
@MainActor
struct LengthField: View {
    let title: LocalizedStringKey
    @Binding var meters: Double
    let system: UnitSystem
    var small = false

    var body: some View {
        let display = Binding<Double>(
            get: { small ? UnitConversion.toDisplaySmall(meters, system) : UnitConversion.toDisplayLength(meters, system) },
            set: { meters = small ? UnitConversion.fromDisplaySmall($0, system) : UnitConversion.fromDisplayLength($0, system) })
        let formatter = UnitFormatter.localized(system)
        HStack {
            Text(title)
            Spacer()
            TextField("", value: display, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 110)
            Text(verbatim: small ? formatter.smallLengthSymbol : formatter.lengthSymbol)
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 24, alignment: .leading)
        }
    }
}

/// Live preview of the manual room with numbered walls.
@MainActor
struct ManualRoomPreview: View {
    let room: RoomGeometry
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        let plan = FloorPlanModel(room: room)
        var layers = PlanLayers.all
        layers.grid = true
        layers.furniture = false
        layers.scaleBar = false
        return Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let layout = PlanLayout.fit(plan, in: CanvasRect(rect), padding: 0.06, includeAnnotations: true)
            context.withCGContext { cgContext in
                FloorPlanDrawer.draw(plan, in: cgContext, rect: rect, layout: layout, style: .blueprint, layers: layers,
                                     formatter: env.formatter, selection: nil)
            }
            for (index, wall) in room.walls.enumerated() {
                let inward = -room.outwardNormal(of: wall)
                let point = layout.transform.apply(wall.midpoint + inward * 0.45)
                let center = CGPoint(x: point.x, y: point.y)
                let circle = Path(ellipseIn: CGRect(x: center.x - 10, y: center.y - 10, width: 20, height: 20))
                context.fill(circle, with: .color(Theme.blue))
                context.draw(Text(verbatim: "\(index + 1)").font(.caption2.weight(.bold)).foregroundStyle(Color.white), at: center)
            }
        }
        .accessibilityLabel(Text("Room preview"))
    }
}
