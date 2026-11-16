// Export formats, the export subject (room or project) and file generation for PDF, PNG, DXF and USDZ.
import SwiftUI
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable {
    case pdf, png, dxf, usdz
    var id: String { rawValue }

    var title: String {
        switch self {
        case .pdf: "PDF"
        case .png: "PNG"
        case .dxf: "DXF"
        case .usdz: "USDZ"
        }
    }

    var subtitle: String {
        switch self {
        case .pdf: String(localized: "True-scale plan + schedule")
        case .png: String(localized: "Image for messages and listings")
        case .dxf: String(localized: "For AutoCAD and other CAD apps")
        case .usdz: String(localized: "3D model for AR and 3D apps")
        }
    }

    var systemImage: String {
        switch self {
        case .pdf: "doc.richtext.fill"
        case .png: "photo.fill"
        case .dxf: "ruler.fill"
        case .usdz: "cube.transparent.fill"
        }
    }

    var fileExtension: String { rawValue }

    var contentType: UTType {
        switch self {
        case .pdf: .pdf
        case .png: .png
        case .dxf: UTType(filenameExtension: "dxf", conformingTo: .data) ?? .data
        case .usdz: .usdz
        }
    }

    /// Pro feature required for this format (PNG is free with a watermark).
    var proFeature: ProFeature? {
        switch self {
        case .pdf: .pdfExport
        case .png: nil
        case .dxf: .dxfExport
        case .usdz: .usdzExport
        }
    }
}

/// What is being exported: a single room or a whole project.
struct ExportSubject: Identifiable {
    let id = UUID()
    var projectName: String
    var roomName: String?
    var rooms: [PDFRoomItem]
    var wholeFloor: FloorPlanModel?
    var usdzURL: URL?
    var hasScannedRooms: Bool

    var isProject: Bool { roomName == nil }

    /// Plan used for PNG and DXF: the room, or the whole floor of a project.
    var drawingPlan: FloorPlanModel? {
        if let wholeFloor { return wholeFloor }
        if rooms.count == 1, let room = rooms.first { return FloorPlanModel(room: room.geometry) }
        return nil
    }

    @MainActor
    static func room(_ room: RoomRecord, store: ProjectStore) -> ExportSubject? {
        guard let geometry = store.geometry(for: room) else { return nil }
        return ExportSubject(projectName: room.project?.name ?? AppConfig.defaultProjectName, roomName: room.name,
                             rooms: [PDFRoomItem(geometry: geometry, snapshots: store.reportSnapshots(for: room))],
                             wholeFloor: nil, usdzURL: store.usdzURL(for: room), hasScannedRooms: room.source == .scanned)
    }

    @MainActor
    static func project(_ project: Project, store: ProjectStore) -> ExportSubject? {
        let records = project.sortedRooms
        let items = records.compactMap { record in
            store.geometry(for: record).map { PDFRoomItem(geometry: $0, snapshots: store.reportSnapshots(for: record)) }
        }
        guard !items.isEmpty else { return nil }
        return ExportSubject(projectName: project.name, roomName: nil, rooms: items, wholeFloor: store.wholeFloorPlan(for: project),
                             usdzURL: store.mergedUSDZURL(for: project),
                             hasScannedRooms: records.contains { $0.source == .scanned })
    }
}

struct ExportOptions {
    var paperSize: PaperSize
    var theme: PlanTheme
    var includeFurniture: Bool
    var includeSchedule: Bool
    var includeCalculators: Bool
}

struct ExportedFile: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let format: ExportFormat
}

@MainActor
enum ExportService {
    enum ExportError: LocalizedError {
        case nothingToDraw
        case modelUnavailable
        case writeFailed

        var errorDescription: String? {
            switch self {
            case .nothingToDraw:
                String(localized: "These rooms were measured separately, so there is no single plan to draw. Export each room, or the PDF report.")
            case .modelUnavailable:
                String(localized: "3D models are created when a room is scanned with LiDAR. Manual and sample rooms have no USDZ model.")
            case .writeFailed:
                String(localized: "The file could not be written.")
            }
        }
    }

    /// "<Project> – <Room> – yyyy-MM-dd.<ext>" with characters that are unsafe in file names removed.
    static func fileName(for subject: ExportSubject, format: ExportFormat, date: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        var parts = [subject.projectName]
        if let room = subject.roomName { parts.append(room) }
        parts.append(formatter.string(from: date))
        let base = parts.joined(separator: " – ")
            .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
            .joined(separator: "-")
        return "\(base).\(format.fileExtension)"
    }

    static func export(_ format: ExportFormat, subject: ExportSubject, options: ExportOptions, env: AppEnvironment,
                       rotationDegrees: Double = 0) throws -> ExportedFile {
        let url = try env.files.exportURL(fileName: fileName(for: subject, format: format))
        let formatter = env.formatter
        let isPro = env.gate.isPro
        switch format {
        case .pdf:
            let company = env.gate.isUnlocked(.companyName) ? env.settings.companyName : nil
            let content = PDFReportContent(projectName: subject.projectName, companyName: company, date: Date(),
                                           wholeFloor: subject.isProject ? subject.wholeFloor : nil, rooms: subject.rooms,
                                           paperSize: options.paperSize, includeFurniture: options.includeFurniture,
                                           includeSchedule: options.includeSchedule, includeCalculators: options.includeCalculators,
                                           formatter: formatter, rotationDegrees: rotationDegrees)
            try write(PDFReportBuilder.makePDF(content), to: url)
        case .png:
            guard var plan = subject.drawingPlan else { throw ExportError.nothingToDraw }
            plan.rotationDegrees = rotationDegrees
            var layers = PlanLayers.all
            layers.furniture = options.includeFurniture
            layers.grid = options.theme == .blueprint
            let metrics = RoomMetrics.total(of: plan.rooms)
            let title = subject.roomName ?? subject.projectName
            let subtitle = subject.roomName == nil ? formatter.area(metrics.floorArea)
                : "\(subject.projectName) · \(formatter.area(metrics.floorArea))"
            let data = PlanImageRenderer.png(for: plan, title: title, subtitle: subtitle, style: PlanStyle.theme(options.theme),
                                             layers: layers, formatter: formatter, watermark: !isPro)
            try write(data, to: url)
        case .dxf:
            guard var plan = subject.drawingPlan else { throw ExportError.nothingToDraw }
            plan.rotationDegrees = 0
            var exporter = DXFExporter(lengthLabel: { formatter.dxfLength($0) }, areaLabel: { formatter.dxfArea($0) })
            exporter.includeFurniture = options.includeFurniture
            let text = exporter.makeDXF(plan: plan)
            guard let data = text.data(using: .utf8) else { throw ExportError.writeFailed }
            try write(data, to: url)
        case .usdz:
            guard let source = subject.usdzURL else { throw ExportError.modelUnavailable }
            try env.files.copyItem(at: source, to: url)
        }
        return ExportedFile(url: url, format: format)
    }

    private static func write(_ data: Data, to url: URL) throws {
        guard !data.isEmpty else { throw ExportError.writeFailed }
        try data.write(to: url, options: .atomic)
    }
}

/// Wraps an exported file for `.fileExporter` ("Save to Files").
struct ExportFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.data] }
    static var writableContentTypes: [UTType] {
        [.pdf, .png, .usdz, .data, UTType(filenameExtension: "dxf", conformingTo: .data) ?? .data]
    }

    let data: Data

    init(url: URL) throws {
        data = try Data(contentsOf: url)
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
