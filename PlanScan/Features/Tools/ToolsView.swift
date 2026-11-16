// Tools tab: renovation calculators as large cards (Pro), plus the calculators hub opened from a room.
import SwiftUI

@MainActor
struct ToolsView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var path: [CalculatorKind] = []
    @State private var paywallReason: PaywallReason?

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Estimate materials from your measured rooms or your own numbers.")
                        .font(.callout)
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.bottom, 4)
                    ForEach(CalculatorKind.allCases) { kind in
                        Button {
                            open(kind)
                        } label: {
                            CalculatorCard(kind: kind, locked: !env.gate.isUnlocked(.calculators))
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
                        .scrollTransition { content, phase in
                            content.opacity(phase.isIdentity ? 1 : 0.6).scaleEffect(phase.isIdentity ? 1 : 0.96)
                        }
                    }
                }
                .padding(.horizontal, Theme.margin)
                .padding(.vertical, 12)
            }
            .appBackground()
            .navigationTitle("Tools")
            .navigationDestination(for: CalculatorKind.self) { kind in
                CalculatorView(kind: kind, initialRoomID: nil)
            }
        }
        .paywallCover($paywallReason)
    }

    private func open(_ kind: CalculatorKind) {
        if env.gate.isUnlocked(.calculators) {
            path.append(kind)
        } else {
            paywallReason = .feature(.calculators)
        }
    }
}

@MainActor
struct CalculatorCard: View {
    let kind: CalculatorKind
    let locked: Bool

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: kind.systemImage)
                .font(.title2)
                .foregroundStyle(Theme.accentGradient)
                .symbolEffect(.bounce, value: locked)
                .frame(width: 56, height: 56)
                .background(Theme.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: kind.displayName)
                    .font(.expanded(.headline, weight: .bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(verbatim: kind.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if locked {
                Badge("PRO", systemImage: "lock.fill", tint: Theme.amber)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundStyle(Theme.textTertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCardBackground()
        .accessibilityElement(children: .combine)
    }
}

/// Calculators opened from a room (prefilled with that room).
@MainActor
struct CalculatorsHubView: View {
    let roomID: UUID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    ForEach(CalculatorKind.allCases) { kind in
                        NavigationLink(value: kind) {
                            CalculatorCard(kind: kind, locked: false)
                        }
                        .buttonStyle(PressableButtonStyle(pressedScale: 0.98))
                    }
                }
                .padding(Theme.margin)
            }
            .appBackground()
            .navigationTitle("Calculators")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CalculatorKind.self) { kind in
                CalculatorView(kind: kind, initialRoomID: roomID)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
