import SwiftUI

struct OnboardingPinnedTitleScrollView<Content: View>: View {
    @State private var showsPinnedTitle = false

    private let title: LocalizedStringKey
    private let content: Content

    init(
        _ title: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            content
        }
        .onScrollGeometryChange(for: Bool.self) { geometry in
            geometry.contentOffset.y > 52
        } action: { _, isPastHero in
            showsPinnedTitle = isPastHero
        }
        .navigationTitle(Text(title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbarBackground(ColorTokens.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(title)
                    .font(.headline)
                    .opacity(showsPinnedTitle ? 1 : 0)
                    .accessibilityHidden(!showsPinnedTitle)
                    .animation(.easeOut(duration: 0.18), value: showsPinnedTitle)
            }
        }
        .background(ColorTokens.background.ignoresSafeArea())
    }
}

struct OnboardingHeroTitle: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 42

    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.system(size: titleSize, weight: .bold, design: .rounded))
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct OnboardingBriefingRevealModifier: ViewModifier {
    let step: OnboardingBriefingRevealStep
    let revealedStep: OnboardingBriefingRevealStep
    let reduceMotion: Bool

    private var isVisible: Bool {
        reduceMotion || revealedStep.rawValue >= step.rawValue
    }

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .blur(radius: reduceMotion || isVisible ? 0 : 3)
            .offset(y: reduceMotion || isVisible ? 0 : 10)
    }
}

private struct OnboardingEntranceModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .opacity(isPresented ? 1 : 0)
            .offset(y: reduceMotion || isPresented ? 0 : 10)
            .onAppear {
                if reduceMotion {
                    isPresented = true
                } else {
                    withAnimation(.easeOut(duration: 0.28)) {
                        isPresented = true
                    }
                }
            }
    }
}

extension View {
    func onboardingEntrance() -> some View {
        modifier(OnboardingEntranceModifier())
    }

    func onboardingBriefingReveal(
        _ step: OnboardingBriefingRevealStep,
        revealedStep: OnboardingBriefingRevealStep,
        reduceMotion: Bool
    ) -> some View {
        modifier(
            OnboardingBriefingRevealModifier(
                step: step,
                revealedStep: revealedStep,
                reduceMotion: reduceMotion
            )
        )
    }
}
