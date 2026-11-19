//
//  OnboardingView.swift
//  Tutoriel du premier lancement (4 pages).
//

import SwiftUI

struct OnboardingView: View {
    @Environment(\.appTheme) private var theme
    let onFinish: () -> Void
    @State private var page = 0

    private struct Page {
        let icon: String
        let color: Color
        let titleKey: String
        let textKey: String
    }

    private let pages: [Page] = [
        Page(icon: "hand.draw.fill", color: .pink, titleKey: "onb1_title", textKey: "onb1_text"),
        Page(icon: "arrow.uturn.backward.circle.fill", color: .orange, titleKey: "onb2_title", textKey: "onb2_text"),
        Page(icon: "square.on.square.fill", color: .purple, titleKey: "onb3_title", textKey: "onb3_text"),
        Page(icon: "lock.shield.fill", color: .green, titleKey: "onb4_title", textKey: "onb4_text")
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button(loc("skip")) { onFinish() }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }
            }
            .frame(height: 44)

            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index], index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation(.snappy) { page += 1 }
                } else {
                    onFinish()
                }
            } label: {
                Text(page < pages.count - 1 ? loc("next") : loc("start"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.gradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
            .frame(maxWidth: 520)
        }
    }

    private func pageView(_ item: Page, index: Int) -> some View {
        VStack(spacing: 26) {
            Spacer()
            if index == 0 {
                demoCard
            } else {
                Image(systemName: item.icon)
                    .font(.system(size: 64))
                    .foregroundStyle(index == 2 ? theme.secondary : item.color)
                    .frame(width: 150, height: 150)
                    .glassBackground(in: Circle())
            }
            VStack(spacing: 12) {
                Text(loc(item.titleKey))
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                Text(loc(item.textKey))
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
        .frame(maxWidth: 560)
    }

    /// Petite carte animée qui montre le geste de swipe.
    private var demoCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(theme.diagonalGradient)
                .frame(width: 150, height: 200)
                .overlay {
                    Image(systemName: "photo")
                        .font(.system(size: 54))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .shadow(color: theme.secondary.opacity(0.45), radius: 20, y: 10)
                .phaseAnimator([0.0, 1.0, 0.0, -1.0]) { content, phase in
                    content
                        .rotationEffect(.degrees(phase * 12), anchor: .bottom)
                        .offset(x: phase * 46)
                } animation: { _ in
                    .easeInOut(duration: 0.9)
                }
            HStack {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Spacer()
                Image(systemName: "heart.circle.fill").foregroundStyle(.green)
            }
            .font(.system(size: 40))
            .frame(width: 290)
        }
        .frame(height: 220)
    }
}
