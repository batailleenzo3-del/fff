//
//  Effects.swift
//  Style visuel : effet Liquid Glass (iOS 26), fond, thème clair/sombre, confettis.
//

import SwiftUI

// MARK: - Liquid Glass

extension View {
    /// Effet « Liquid Glass » d'iOS 26 (verre flou et brillant).
    /// Sur iOS 17–18, un fond translucide équivalent est utilisé.
    @ViewBuilder
    func glassBackground<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            self.glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else if let tint {
            self.background(tint.opacity(0.85), in: shape)
        } else {
            self.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.08), lineWidth: 1))
        }
    }

    /// Applique le thème choisi dans les Réglages (système, clair ou sombre).
    func appAppearance() -> some View {
        modifier(AppAppearanceModifier())
    }
}

@available(iOS 26.0, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

struct AppAppearanceModifier: ViewModifier {
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceOption.system.rawValue

    func body(content: Content) -> some View {
        content.preferredColorScheme(AppearanceOption(rawValue: appearanceRaw)?.colorScheme)
    }
}

// MARK: - Bouton rond en verre

struct GlassIconButton: View {
    let icon: String
    var tint: Color = .primary
    var size: CGFloat = 44
    var accessibility: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: size, height: size)
                .glassBackground(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibility)
    }
}

// MARK: - Fond de l'app

struct AppBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let dark = colorScheme == .dark
        LinearGradient(
            colors: dark
                ? [Color(red: 0.05, green: 0.05, blue: 0.09), Color(red: 0.11, green: 0.07, blue: 0.16)]
                : [Color(red: 0.98, green: 0.97, blue: 1.0), Color(red: 0.92, green: 0.89, blue: 0.97)],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(Color.purple.opacity(dark ? 0.28 : 0.16))
                .frame(width: 460, height: 460)
                .blur(radius: 120)
                .offset(y: -220)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(Color.pink.opacity(dark ? 0.16 : 0.12))
                .frame(width: 360, height: 360)
                .blur(radius: 110)
                .offset(x: 120, y: 120)
        }
        .ignoresSafeArea()
    }
}

/// Dégradé rose → violet de l'app.
extension LinearGradient {
    static let brand = LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing)
}

// MARK: - Confettis

struct ConfettiPiece {
    let x: Double
    let delay: Double
    let speed: Double
    let spin: Double
    let wobble: Double
    let phase: Double
    let width: Double
    let height: Double
    let color: Color
}

/// Pluie de confettis déclenchée à chaque changement de `trigger`.
struct ConfettiView: View {
    let trigger: Int

    @State private var startDate: Date?
    @State private var pieces: [ConfettiPiece] = []
    private let duration: Double = 3.2

    var body: some View {
        TimelineView(.animation(paused: startDate == nil)) { timeline in
            Canvas { context, size in
                guard let startDate else { return }
                let elapsed = timeline.date.timeIntervalSince(startDate)
                for piece in pieces {
                    let time = elapsed - piece.delay
                    guard time > 0 else { continue }
                    let x = piece.x * size.width + sin(time * piece.wobble + piece.phase) * 24
                    let y = -30 + time * piece.speed * size.height * 0.45
                    let opacity = max(0, 1 - max(0, elapsed - duration + 0.8) / 0.8)
                    var pieceContext = context
                    pieceContext.translateBy(x: x, y: y)
                    pieceContext.rotate(by: .radians(time * piece.spin))
                    let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)
                    pieceContext.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(piece.color.opacity(opacity)))
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
        .onChange(of: trigger) { _, _ in
            launch()
        }
    }

    private func launch() {
        let colors: [Color] = [.pink, .purple, .yellow, .mint, .orange, .cyan, .white]
        pieces = (0..<140).map { _ in
            ConfettiPiece(
                x: Double.random(in: 0...1),
                delay: Double.random(in: 0...0.6),
                speed: Double.random(in: 0.7...1.4),
                spin: Double.random(in: -8...8),
                wobble: Double.random(in: 2...5),
                phase: Double.random(in: 0...(2 * .pi)),
                width: Double.random(in: 6...10),
                height: Double.random(in: 10...16),
                color: colors.randomElement() ?? .pink
            )
        }
        let start = Date()
        startDate = start
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(duration))
            if startDate == start { startDate = nil }
        }
    }
}
