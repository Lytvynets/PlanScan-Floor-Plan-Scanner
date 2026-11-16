// Export sheet: format cards with Pro locks, options, then a preview with Share and Save to Files.
import PDFKit
import SwiftUI
import UniformTypeIdentifiers

extension ExportedFile: Hashable {
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
struct ExportSheet: View {
    let subject: ExportSubject
    var rotationDegrees: Double = 0

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExportFormat = .pdf
    @State private var paperSize: PaperSize = .a4
    @State private var theme: PlanTheme = .blueprint
    @State private var includeFurniture = true
    @State private var includeSchedule = true
    @State private var includeCalculators = true
    @State private var exported: ExportedFile?
    @State private var errorMessage: String?
    @State private var paywallReason: PaywallReason?
    @State private var didSetup = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SectionHeader("Format")
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                        ForEach(ExportFormat.allCases) { item in
                            formatCard(item)
                        }
                    }
                    if let note = availabilityNote(for: format) {
                        Label(note, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    SectionHeader("Options")
                    options
                    PrimaryButton("Preview", systemImage: "eye.fill", isEnabled: isAvailable(format)) {
                        generate()
                    }
                }
                .padding(Theme.margin)
            }
            .appBackground()
            .navigationTitle(subject.isProject ? Text("Export project") : Text("Export room"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .navigationDestination(item: $exported) { file in
                ExportPreviewView(file: file, plan: subject.drawingPlan)
            }
            .alert(Text("Export failed"), isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(verbatim: errorMessage ?? "")
            }
            .paywallCover($paywallReason)
            .onAppear(perform: setup)
        }
    }

    private func setup() {
        guard !didSetup else { return }
        didSetup = true
        paperSize = env.settings.paperSize
        theme = env.settings.planTheme
        includeFurniture = env.settings.showFurnitureByDefault
    }

    private func isAvailable(_ item: ExportFormat) -> Bool {
        switch item {
        case .pdf: return true
        case .png, .dxf: return subject.drawingPlan != nil
        case .usdz: return subject.usdzURL != nil
        }
    }

    private func availabilityNote(for item: ExportFormat) -> String? {
        switch item {
        case .pdf:
            return nil
        case .png, .dxf:
            return isAvailable(item) ? nil
                : String(localized: "These rooms were measured separately, so there is no single plan to draw. Export each room, or the PDF report.")
        case .usdz:
            if isAvailable(item) { return nil }
            return subject.hasScannedRooms
                ? String(localized: "Open a scanned room to export its 3D model.")
                : String(localized: "3D models are created when a room is scanned with LiDAR. Manual and sample rooms have no USDZ model.")
        }
    }

    private func formatCard(_ item: ExportFormat) -> some View {
        let isSelected = format == item
        let locked = item.proFeature.map { !env.gate.isUnlocked($0) } ?? false
        return Button {
            Haptics.shared.selection()
            if locked, let feature = item.proFeature {
                paywallReason = .feature(feature)
            } else {
                withAnimation(Theme.quickSpring) { format = item }
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: item.systemImage)
                        .font(.title3)
                        .foregroundStyle(isSelected ? Theme.cyan : Theme.textSecondary)
                    Spacer()
                    if locked {
                        Badge("PRO", systemImage: "lock.fill", tint: Theme.amber)
                    } else if item == .png && !env.gate.isPro {
                        Image(systemName: "drop.halffull")
                            .foregroundStyle(Theme.textTertiary)
                            .accessibilityLabel(Text("With watermark"))
                    }
                }
                Text(verbatim: item.title)
                    .font(.expanded(.headline, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(verbatim: item.subtitle)
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
            .glassCardBackground(cornerRadius: 18, highlighted: isSelected)
            .opacity(isAvailable(item) ? 1 : 0.45)
        }
        .buttonStyle(PressableButtonStyle(pressedScale: 0.97))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var options: some View {
        VStack(spacing: 0) {
            if format == .pdf {
                optionRow {
                    Picker("Paper size", selection: $paperSize) {
                        ForEach(PaperSize.allCases) { size in
                            Text(verbatim: size.displayName).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            if format == .png {
                optionRow {
                    Picker("Theme", selection: $theme) {
                        ForEach(PlanTheme.allCases) { item in
                            Text(verbatim: item.displayName).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            if format != .usdz {
                optionRow { Toggle("Include furniture", isOn: $includeFurniture) }
            }
            if format == .pdf {
                optionRow { Toggle("Include schedule page", isOn: $includeSchedule) }
                optionRow { Toggle("Include calculator results", isOn: $includeCalculators) }
            }
            if format == .usdz {
                optionRow {
                    Text("The parametric 3D model saved with the scan.")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
            }
        }
        .tint(Theme.cyan)
        .glassCardBackground(cornerRadius: 18)
    }

    private func optionRow<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func generate() {
        if let feature = format.proFeature, !env.gate.isUnlocked(feature) {
            paywallReason = .feature(feature)
            return
        }
        let options = ExportOptions(paperSize: paperSize, theme: theme, includeFurniture: includeFurniture,
                                    includeSchedule: includeSchedule, includeCalculators: includeCalculators)
        do {
            exported = try ExportService.export(format, subject: subject, options: options, env: env, rotationDegrees: rotationDegrees)
            Haptics.shared.success()
        } catch {
            Haptics.shared.error()
            errorMessage = error.localizedDescription
        }
    }
}

/// Preview of an exported file with Share and Save to Files.
@MainActor
struct ExportPreviewView: View {
    let file: ExportedFile
    let plan: FloorPlanModel?

    @State private var showFileExporter = false
    @State private var document: ExportFileDocument?
    @State private var quickLookURL: URL?
    @State private var savedMessage: String?

    var body: some View {
        VStack(spacing: 14) {
            preview
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(Theme.stroke))
            Text(verbatim: file.url.lastPathComponent)
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
            HStack(spacing: 12) {
                ShareLink(item: file.url) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                SecondaryButton("Save to Files", systemImage: "folder.fill") {
                    document = try? ExportFileDocument(url: file.url)
                    showFileExporter = document != nil
                }
            }
        }
        .padding(Theme.margin)
        .appBackground()
        .navigationTitle(Text(verbatim: file.format.title))
        .navigationBarTitleDisplayMode(.inline)
        .fileExporter(isPresented: $showFileExporter, document: document, contentType: file.format.contentType,
                      defaultFilename: file.url.deletingPathExtension().lastPathComponent) { result in
            switch result {
            case .success:
                Haptics.shared.success()
                savedMessage = String(localized: "Saved to Files.")
            case .failure(let error):
                savedMessage = error.localizedDescription
            }
        }
        .background(QuickLookPresenter(url: $quickLookURL))
        .alert(Text("Save to Files"), isPresented: Binding(get: { savedMessage != nil }, set: { if !$0 { savedMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: savedMessage ?? "")
        }
    }

    @ViewBuilder
    private var preview: some View {
        switch file.format {
        case .pdf:
            PDFKitView(url: file.url)
        case .png:
            if let image = UIImage(contentsOfFile: file.url.path) {
                ScrollView([.horizontal, .vertical]) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(minWidth: 320)
                }
                .background(Color.black)
            } else {
                ContentUnavailableView("Preview unavailable", systemImage: "photo")
            }
        case .dxf:
            VStack(spacing: 12) {
                PlanThumbnail(plan: plan, showsFurniture: true, theme: .paper)
                    .frame(maxHeight: .infinity)
                Text("DXF R12 drawing in meters with layers for walls, doors, windows, furniture, text and dimensions.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 12)
            }
            .background(Theme.surface)
        case .usdz:
            VStack(spacing: 16) {
                Image(systemName: "cube.transparent.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.accentGradient)
                Text("USDZ 3D model")
                    .font(.headline)
                    .foregroundStyle(Theme.textPrimary)
                Button {
                    quickLookURL = file.url
                } label: {
                    Label("Open 3D preview", systemImage: "arkit")
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.blue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.surface)
        }
    }
}

/// PDFKit viewer.
@MainActor
struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = UIColor(hex: 0x0E1628)
        view.document = PDFDocument(url: url)
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {
        if view.document?.documentURL != url {
            view.document = PDFDocument(url: url)
        }
    }
}
