// Root state machine: Splash → Onboarding → Paywall → Main, with custom opacity + scale + blur stage transitions.
import SwiftUI

enum AppStage: Equatable {
    case splash
    case onboarding
    case paywall(PaywallReason)
    case main
}

@MainActor
struct RootView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var stage: AppStage = .splash

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch stage {
            case .splash:
                SplashView { advanceFromSplash() }
                    .transition(.stage)
            case .onboarding:
                OnboardingView { go(to: .paywall(.onboarding)) }
                    .transition(.stage)
            case .paywall(let reason):
                PaywallView(reason: reason) { go(to: .main) }
                    .transition(.stage)
            case .main:
                MainTabView()
                    .transition(.stage)
            }
        }
        .task { env.bootstrap() }
    }

    private func advanceFromSplash() {
        if !env.settings.hasCompletedOnboarding {
            go(to: .onboarding)
        } else if !env.store.isPro && env.settings.isLaunchPaywallDue {
            go(to: .paywall(.launch))
        } else {
            go(to: .main)
        }
    }

    private func go(to next: AppStage) {
        if case .paywall = next { env.settings.lastPaywallShownAt = Date() }
        withAnimation(.easeInOut(duration: 0.55)) {
            stage = next
        }
    }
}

/// Opacity + scale + blur used between root stages.
@MainActor
private struct StageTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let blur: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale)
            .blur(radius: blur)
    }
}

extension AnyTransition {
    static var stage: AnyTransition {
        .asymmetric(
            insertion: .modifier(active: StageTransitionModifier(opacity: 0, scale: 1.06, blur: 14),
                                 identity: StageTransitionModifier(opacity: 1, scale: 1, blur: 0)),
            removal: .modifier(active: StageTransitionModifier(opacity: 0, scale: 0.94, blur: 14),
                               identity: StageTransitionModifier(opacity: 1, scale: 1, blur: 0)))
    }
}
