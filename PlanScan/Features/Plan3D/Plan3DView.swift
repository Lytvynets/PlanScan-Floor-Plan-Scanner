// 3D tab: dollhouse model with reset-camera and cutaway controls, plus "View in AR" via Quick Look for scanned rooms.
import QuickLook
import SwiftUI

@MainActor
struct Plan3DView: View {
    let plan: FloorPlanModel
    let usdzURL: URL?
    let isScanned: Bool

    @Environment(AppEnvironment.self) private var env
    @State private var cutaway = false
    @State private var resetToken = 0
    @State private var arURL: URL?
    @State private var paywallReason: PaywallReason?
    @State private var showModelMissing = false

    private var background: UIColor {
        env.settings.planTheme == .blueprint ? UIColor(hex: 0x0A1A33) : UIColor(hex: 0xEEF1F5)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            DollhouseSceneView(plan: plan, cutaway: cutaway, resetToken: resetToken, background: background)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous).strokeBorder(Theme.stroke))
                .padding(.horizontal, 12)
                .accessibilityLabel(Text("3D model of the room. Drag to rotate, pinch to zoom."))
            FloatingToolbar {
                ToolbarIconButton(systemImage: "arrow.counterclockwise", label: "Reset camera") {
                    resetToken += 1
                }
                ToolbarIconButton(systemImage: "scissors", label: "Cutaway", isActive: cutaway) {
                    withAnimation(Theme.quickSpring) { cutaway.toggle() }
                }
                if isScanned {
                    Button {
                        viewInAR()
                    } label: {
                        Label("View in AR", systemImage: "arkit")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.background)
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(Theme.accentGradient, in: Capsule())
                    }
                    .buttonStyle(PressableButtonStyle(pressedScale: 0.95))
                }
            }
            .padding(.bottom, 16)
        }
        .background(QuickLookPresenter(url: $arURL))
        .paywallCover($paywallReason)
        .alert(Text("3D model unavailable"), isPresented: $showModelMissing) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("This scan has no saved 3D model. Rescan the room to view it in AR.")
        }
    }

    private func viewInAR() {
        guard env.gate.isUnlocked(.arView) else {
            paywallReason = .feature(.arView)
            return
        }
        guard let usdzURL else {
            showModelMissing = true
            return
        }
        arURL = usdzURL
    }
}

/// Presents QLPreviewController modally for a USDZ file; Quick Look provides the AR / Object modes.
@MainActor
struct QuickLookPresenter: UIViewControllerRepresentable {
    @Binding var url: URL?

    func makeCoordinator() -> Coordinator { Coordinator(url: $url) }

    func makeUIViewController(context: Context) -> UIViewController {
        let host = UIViewController()
        host.view.backgroundColor = .clear
        host.view.isUserInteractionEnabled = false
        return host
    }

    func updateUIViewController(_ host: UIViewController, context: Context) {
        context.coordinator.binding = $url
        guard let url, host.presentedViewController == nil else { return }
        context.coordinator.previewURL = url
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        preview.delegate = context.coordinator
        DispatchQueue.main.async {
            host.present(preview, animated: true)
        }
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var binding: Binding<URL?>
        var previewURL: URL?

        init(url: Binding<URL?>) {
            binding = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            previewURL == nil ? 0 : 1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            (previewURL ?? URL(fileURLWithPath: "/")) as NSURL
        }

        nonisolated func previewControllerDidDismiss(_ controller: QLPreviewController) {
            // Quick Look calls its delegate on the main thread.
            MainActor.assumeIsolated {
                binding.wrappedValue = nil
            }
        }
    }
}
