// One calculator: room prefill, unit-aware inputs, big animated result, "Add to report" and "Share as text".
import SwiftData
import SwiftUI

@MainActor
struct CalculatorView: View {
    let kind: CalculatorKind
    let initialRoomID: UUID?

    @Environment(AppEnvironment.self) private var env
    @Query(sort: \RoomRecord.createdAt, order: .reverse) private var rooms: [RoomRecord]
    @State private var roomID: UUID?
    @State private var paint = PaintInputs()
    @State private var flooring = FlooringInputs()
    @State private var baseboards = BaseboardInputs()
    @State private var wallpaper = WallpaperInputs()
    @State private var tiles = TileInputs()
    @State private var didSetup = false

    private var system: UnitSystem { env.settings.unitSystem }
    private var selectedRoom: RoomRecord? { rooms.first { $0.id == roomID } }

    private var snapshot: CalculatorSnapshot {
        switch kind {
        case .paint: .paint(paint)
        case .flooring: .flooring(flooring)
        case .baseboards: .baseboards(baseboards)
        case .wallpaper: .wallpaper(wallpaper)
        case .tiles: .tiles(tiles)
        }
    }

    var body: some View {
        Form {
            Section {
                Picker("Room", selection: $roomID) {
                    Text("Manual input").tag(UUID?.none)
                    ForEach(rooms) { room in
                        Text(verbatim: roomLabel(room)).tag(Optional(room.id))
                    }
                }
            } header: {
                Text("Prefill from a room")
            }

            Section {
                inputs
            } header: {
                Text("Inputs")
            }

            Section {
                resultView
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                if let room = selectedRoom {
                    Toggle(isOn: Binding(get: { env.projects.isInReport(kind, room: room) },
                                         set: { env.projects.setReportSnapshot($0 ? snapshot : nil, kind: kind, for: room) })) {
                        Label("Add to report", systemImage: "doc.badge.plus")
                    }
                    .tint(Theme.cyan)
                } else {
                    Label("Choose a room to add this result to its PDF report.", systemImage: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                ShareLink(item: CalculatorSummary.shareText(snapshot, roomName: selectedRoom?.name, formatter: env.formatter)) {
                    Label("Share as text", systemImage: "square.and.arrow.up")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .appBackground()
        .navigationTitle(Text(verbatim: kind.displayName))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: setup)
        .onChange(of: roomID) { prefill() }
        .onChange(of: snapshot) {
            if let room = selectedRoom, env.projects.isInReport(kind, room: room) {
                env.projects.setReportSnapshot(snapshot, kind: kind, for: room)
            }
        }
    }

    private func roomLabel(_ room: RoomRecord) -> String {
        if let project = room.project?.name { return "\(room.name) · \(project)" }
        return room.name
    }

    // MARK: Inputs

    @ViewBuilder
    private var inputs: some View {
        switch kind {
        case .paint:
            AreaField(title: "Wall area (net)", squareMeters: $paint.wallArea, system: system)
            Toggle("Include ceiling", isOn: $paint.includeCeiling)
                .tint(Theme.cyan)
            if paint.includeCeiling {
                AreaField(title: "Ceiling area", squareMeters: $paint.ceilingArea, system: system)
            }
            Stepper(value: $paint.coats, in: 1...5) {
                HStack {
                    Text("Coats")
                    Spacer()
                    Text(verbatim: "\(paint.coats)").monospacedDigit().foregroundStyle(Theme.textSecondary)
                }
            }
            CoverageField(coverage: $paint.coverage, system: system)
        case .flooring:
            AreaField(title: "Floor area", squareMeters: $flooring.area, system: system)
            PercentField(title: "Waste", value: $flooring.wastePercent)
            AreaField(title: "Pack size (optional)", squareMeters: $flooring.packSize, system: system)
        case .baseboards:
            LengthField(title: "Perimeter", meters: $baseboards.perimeter, system: system)
            LengthField(title: "Door widths", meters: $baseboards.doorWidths, system: system)
            LengthField(title: "Piece length", meters: $baseboards.pieceLength, system: system)
        case .wallpaper:
            AreaField(title: "Wall area (net)", squareMeters: $wallpaper.wallArea, system: system)
            LengthField(title: "Wall height", meters: $wallpaper.wallHeight, system: system)
            LengthField(title: "Roll width", meters: $wallpaper.rollWidth, system: system, small: true)
            LengthField(title: "Roll length", meters: $wallpaper.rollLength, system: system)
            LengthField(title: "Pattern repeat", meters: $wallpaper.patternRepeat, system: system, small: true)
        case .tiles:
            AreaField(title: "Floor area", squareMeters: $tiles.area, system: system)
            LengthField(title: "Tile width", meters: $tiles.tileWidth, system: system, small: true)
            LengthField(title: "Tile length", meters: $tiles.tileLength, system: system, small: true)
            PercentField(title: "Waste", value: $tiles.wastePercent)
            Stepper(value: $tiles.tilesPerBox, in: 0...200) {
                HStack {
                    Text("Tiles per box")
                    Spacer()
                    Text(verbatim: tiles.tilesPerBox == 0 ? "—" : "\(tiles.tilesPerBox)")
                        .monospacedDigit()
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
    }

    private var resultView: some View {
        let result = CalculatorSummary.result(snapshot, formatter: env.formatter)
        return VStack(spacing: 8) {
            Image(systemName: kind.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.accentGradient)
            Text(verbatim: result)
                .font(.expanded(.largeTitle, weight: .bold))
                .monospacedDigit()
                .foregroundStyle(Theme.textPrimary)
                .contentTransition(.numericText())
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .animation(Theme.spring, value: result)
            Text("Includes the waste allowance shown above.")
                .font(.caption)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .glassCardBackground()
    }

    // MARK: Prefill

    private func setup() {
        guard !didSetup else { return }
        didSetup = true
        applyUnitDefaults()
        if let initialRoomID {
            roomID = initialRoomID
        }
        prefill()
    }

    private func applyUnitDefaults() {
        if system == .imperial {
            paint.coverage = PaintInputs.defaultImperialCoverage / UnitConversion.squareFeetPerSquareMeter / UnitConversion.litersPerGallon
            baseboards.pieceLength = 8 * UnitConversion.metersPerFoot
        }
    }

    private func prefill() {
        guard let room = selectedRoom, let geometry = env.projects.geometry(for: room) else { return }
        if let saved = env.projects.reportSnapshots(for: room).first(where: { $0.kind == kind }) {
            load(saved)
            return
        }
        let metrics = RoomMetrics(room: geometry)
        switch kind {
        case .paint:
            let coverage = paint.coverage
            paint = PaintInputs(room: metrics)
            paint.coverage = coverage
        case .flooring:
            flooring = FlooringInputs(room: metrics)
        case .baseboards:
            baseboards = BaseboardInputs(room: metrics, system: system)
        case .wallpaper:
            wallpaper = WallpaperInputs(room: metrics)
        case .tiles:
            tiles = TileInputs(room: metrics)
        }
    }

    private func load(_ snapshot: CalculatorSnapshot) {
        switch snapshot {
        case .paint(let value): paint = value
        case .flooring(let value): flooring = value
        case .baseboards(let value): baseboards = value
        case .wallpaper(let value): wallpaper = value
        case .tiles(let value): tiles = value
        }
    }
}

/// Unit-aware area field that stores square meters.
@MainActor
struct AreaField: View {
    let title: LocalizedStringKey
    @Binding var squareMeters: Double
    let system: UnitSystem

    var body: some View {
        let display = Binding<Double>(get: { UnitConversion.toDisplayArea(squareMeters, system) },
                                      set: { squareMeters = max(0, UnitConversion.fromDisplayArea($0, system)) })
        let formatter = UnitFormatter.localized(system)
        HStack {
            Text(title)
            Spacer()
            TextField("", value: display, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 110)
            Text(verbatim: formatter.lengthAreaSymbol)
                .foregroundStyle(Theme.textSecondary)
                .frame(minWidth: 28, alignment: .leading)
        }
    }
}

/// Paint coverage: m² per liter (metric) or ft² per gallon (imperial); stored as m²/L.
@MainActor
struct CoverageField: View {
    @Binding var coverage: Double
    let system: UnitSystem

    var body: some View {
        let factor = UnitConversion.squareFeetPerSquareMeter * UnitConversion.litersPerGallon
        let display = Binding<Double>(get: { system == .metric ? coverage : coverage * factor },
                                      set: { coverage = max(0.1, system == .metric ? $0 : $0 / factor) })
        let formatter = UnitFormatter.localized(system)
        HStack {
            Text("Coverage")
            Spacer()
            TextField("", value: display, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 90)
            Text(verbatim: system == .metric ? "\(formatter.symbols.squareMeter)/\(formatter.symbols.liter)"
                                             : "\(formatter.symbols.squareFoot)/\(formatter.symbols.gallon)")
                .foregroundStyle(Theme.textSecondary)
        }
    }
}

@MainActor
struct PercentField: View {
    let title: LocalizedStringKey
    @Binding var value: Double

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("", value: $value, format: .number.precision(.fractionLength(0...1)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 80)
            Text(verbatim: "%")
                .foregroundStyle(Theme.textSecondary)
        }
    }
}
