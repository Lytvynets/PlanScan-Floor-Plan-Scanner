// Settings: units, plan theme, paper size, PDF branding, furniture default, haptics, subscription, legal, support, debug.
import StoreKit
import SwiftUI

@MainActor
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    @State private var showManageSubscriptions = false
    @State private var paywallReason: PaywallReason?
    @State private var isRestoring = false
    @State private var message: String?
    @State private var showDeleteAll = false

    var body: some View {
        @Bindable var settings = env.settings
        NavigationStack {
            Form {
                Section {
                    proRow
                    if env.store.isPro {
                        Button {
                            showManageSubscriptions = true
                        } label: {
                            Label("Manage subscription", systemImage: "creditcard.fill")
                        }
                    }
                    Button {
                        restore()
                    } label: {
                        HStack {
                            Label("Restore purchases", systemImage: "arrow.clockwise")
                            if isRestoring {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isRestoring)
                } header: {
                    Text("PlanScan Pro")
                }

                Section {
                    Picker(selection: $settings.unitPreference) {
                        ForEach(UnitPreference.allCases) { option in
                            Text(verbatim: option.displayName).tag(option)
                        }
                    } label: {
                        Label("Units", systemImage: "ruler")
                    }
                    Picker(selection: $settings.planTheme) {
                        ForEach(PlanTheme.allCases) { option in
                            Text(verbatim: option.displayName).tag(option)
                        }
                    } label: {
                        Label("Plan theme", systemImage: "paintpalette")
                    }
                    Picker(selection: $settings.paperSize) {
                        ForEach(PaperSize.allCases) { option in
                            Text(verbatim: option.displayName).tag(option)
                        }
                    } label: {
                        Label("Paper size", systemImage: "doc")
                    }
                    Toggle(isOn: $settings.showFurnitureByDefault) {
                        Label("Show furniture by default", systemImage: "sofa")
                    }
                    Toggle(isOn: $settings.hapticsEnabled) {
                        Label("Haptics", systemImage: "hand.tap")
                    }
                } header: {
                    Text("Plans")
                }

                Section {
                    if env.gate.isUnlocked(.companyName) {
                        TextField("Company or author name", text: $settings.companyName)
                    } else {
                        Button {
                            paywallReason = .feature(.companyName)
                        } label: {
                            HStack {
                                Text("Company or author name")
                                    .foregroundStyle(Theme.textPrimary)
                                Spacer()
                                Badge("PRO", systemImage: "lock.fill", tint: Theme.amber)
                            }
                        }
                    }
                } header: {
                    Text("PDF reports")
                } footer: {
                    Text("Printed in the header of every PDF page.")
                }

                Section {
                    Link(destination: AppConfig.termsURL) {
                        Label("Terms of Use", systemImage: "doc.text")
                    }
                    Link(destination: AppConfig.privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                    Button {
                        openURL(AppConfig.supportMailURL)
                    } label: {
                        Label("Contact support", systemImage: "envelope")
                    }
                    LabeledContent {
                        Text(verbatim: AppConfig.appVersion)
                            .monospacedDigit()
                    } label: {
                        Label("Version", systemImage: "info.circle")
                    }
                } header: {
                    Text("About")
                } footer: {
                    Text("Scans are processed on your device. PlanScan has no accounts and no analytics.")
                }

                #if DEBUG
                debugSection
                #endif
            }
            .scrollContentBackground(.hidden)
            .appBackground()
            .tint(Theme.cyan)
            .navigationTitle("Settings")
        }
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
        .paywallCover($paywallReason)
        .alert(Text("PlanScan"), isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: message ?? "")
        }
        .confirmationDialog(Text("Delete all data?"), isPresented: $showDeleteAll, titleVisibility: .visible) {
            Button("Delete all data", role: .destructive) {
                env.projects.deleteAllData()
                env.settings.sampleSeeded = false
            }
        } message: {
            Text("All projects, rooms and files will be removed from this device.")
        }
    }

    private var proRow: some View {
        HStack(spacing: 14) {
            Image(systemName: env.store.isPro ? "checkmark.seal.fill" : "sparkles")
                .font(.title2)
                .foregroundStyle(env.store.isPro ? AnyShapeStyle(Theme.mint) : AnyShapeStyle(Theme.accentGradient))
                .symbolEffect(.pulse, isActive: !env.store.isPro)
            VStack(alignment: .leading, spacing: 2) {
                Text(env.store.isPro ? "Pro is active" : "Free plan")
                    .font(.headline)
                Text(env.store.isPro ? "Thank you for supporting PlanScan." : "Unlimited rooms, true-scale PDF, DXF, AR and calculators.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
            if !env.store.isPro {
                Button("Upgrade") { paywallReason = .launch }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.blue)
            }
        }
        .padding(.vertical, 4)
    }

    private func restore() {
        isRestoring = true
        Task {
            do {
                let active = try await env.store.restore()
                message = active ? String(localized: "Your Pro subscription has been restored.")
                    : String(localized: "No active subscription was found for this Apple Account.")
            } catch {
                message = error.localizedDescription
            }
            isRestoring = false
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section {
            Toggle("Debug: Pro unlocked", isOn: Binding(get: { env.settings.debugProOverride }, set: { value in
                env.settings.debugProOverride = value
                env.store.debugProOverride = value
            }))
            Button("Reset onboarding") {
                env.settings.resetOnboarding()
                message = String(localized: "Onboarding will be shown on the next launch.")
            }
            Button("Re-seed the sample project") {
                do {
                    let project = try SampleDataLoader.reseed(store: env.projects)
                    env.router.openProject(project.id)
                } catch {
                    message = error.localizedDescription
                }
            }
            Button("Delete all data", role: .destructive) {
                showDeleteAll = true
            }
        } header: {
            Text(verbatim: "Debug")
        }
    }
    #endif
}
