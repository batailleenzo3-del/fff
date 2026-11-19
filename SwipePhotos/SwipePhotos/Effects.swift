//
//  Effects.swift
//  Style visuel : couleurs de thème, effet Liquid Glass (iOS 26) et sa transparence,
//  fond de l'app, fond photo flou, confettis.
//

import SwiftUI
import Combine
import Photos
import UIKit

// MARK: - Couleurs de thème

/// Couleur d'accentuation choisie dans les Réglages.
nonisolated enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case neon, ocean, emerald, sunset, ruby, gold, lavender, graphite

    var id: String { rawValue }

    var title: String { L10n.t("theme_\(rawValue)") }

    var primary: Color {
        switch self {
        case .neon: return Color(red: 1.00, green: 0.18, blue: 0.47)
        case .ocean: return Color(red: 0.10, green: 0.72, blue: 1.00)
        case .emerald: return Color(red: 0.16, green: 0.84, blue: 0.56)
        case .sunset: return Color(red: 1.00, green: 0.56, blue: 0.16)
        case .ruby: return Color(red: 1.00, green: 0.24, blue: 0.30)
        case .gold: return Color(red: 1.00, green: 0.80, blue: 0.22)
        case .lavender: return Color(red: 0.70, green: 0.56, blue: 1.00)
        case .graphite: return Color(red: 0.62, green: 0.64, blue: 0.70)
        }
    }

    var secondary: Color {
        switch self {
        case .neon: return Color(red: 0.60, green: 0.23, blue: 1.00)
        case .ocean: return Color(red: 0.24, green: 0.32, blue: 1.00)
        case .emerald: return Color(red: 0.00, green: 0.58, blue: 0.62)
        case .sunset: return Color(red: 1.00, green: 0.22, blue: 0.42)
        case .ruby: return Color(red: 0.72, green: 0.04, blue: 0.28)
        case .gold: return Color(red: 1.00, green: 0.50, blue: 0.10)
        case .lavender: return Color(red: 0.38, green: 0.34, blue: 0.96)
        case .graphite: return Color(red: 0.30, green: 0.32, blue: 0.38)
        }
    }

    var gradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .leading, endPoint: .trailing)
    }

    var diagonalGradient: LinearGradient {
        LinearGradient(colors: [primary, secondary], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Niveau de transparence de l'effet verre.
nonisolated enum GlassLevel: String, CaseIterable, Identifiable, Sendable {
    case subtle, balanced, max

    var id: String { rawValue }

    var title: String {
        switch self {
        case .subtle: return L10n.t("glass_subtle")
        case .balanced: return L10n.t("glass_balanced")
        case .max: return L10n.t("glass_max")
        }
    }
}

nonisolated struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .neon
}

nonisolated struct GlassLevelKey: EnvironmentKey {
    static let defaultValue: GlassLevel = .balanced
}

extension EnvironmentValues {
    /// Couleur de thème courante (lue dans les écrans avec @Environment(\.appTheme)).
    nonisolated var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }

    /// Transparence du verre courante.
    nonisolated var glassLevel: GlassLevel {
        get { self[GlassLevelKey.self] }
        set { self[GlassLevelKey.self] = newValue }
    }
}

// MARK: - Liquid Glass

extension View {
    /// Effet « Liquid Glass » d'iOS 26 (verre flou et brillant), avec la transparence choisie.
    /// Sur iOS 17–18, un fond translucide équivalent est utilisé.
    func glassBackground<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        modifier(GlassModifier(shape: shape, tint: tint, interactive: interactive))
    }

    /// Applique le thème clair/sombre, la couleur d'accentuation et la transparence choisis.
    func appAppearance() -> some View {
        modifier(AppAppearanceModifier())
    }
}

struct GlassModifier<S: Shape>: ViewModifier {
    let shape: S
    let tint: Color?
    let interactive: Bool
    @Environment(\.glassLevel) private var level

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(makeGlass(level: level, tint: tint, interactive: interactive), in: shape)
        } else if let tint {
            content.background(tint.opacity(level == .max ? 0.55 : 0.85), in: shape)
        } else {
            content
                .background(fallbackStyle, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(level == .max ? 0.14 : 0.08), lineWidth: 1))
        }
    }

    private var fallbackStyle: AnyShapeStyle {
        switch level {
        case .subtle: return AnyShapeStyle(.regularMaterial)
        case .balanced: return AnyShapeStyle(.ultraThinMaterial)
        case .max: return AnyShapeStyle(.ultraThinMaterial.opacity(0.55))
        }
    }
}

@available(iOS 26.0, *)
private func makeGlass(level: GlassLevel, tint: Color?, interactive: Bool) -> Glass {
    var glass: Glass
    switch level {
    case .max:
        glass = .clear
    case .balanced:
        glass = .regular
    case .subtle:
        glass = .regular
    }
    if let tint {
        glass = glass.tint(level == .max ? tint.opacity(0.6) : tint)
    } else if level == .subtle {
        glass = glass.tint(Color(uiColor: .systemBackground).opacity(0.55))
    }
    if interactive { glass = glass.interactive() }
    return glass
}

/// Regroupe des éléments en verre pour qu'ils fusionnent joliment (iOS 26).
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 12
    @ViewBuilder var content: Content

    var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

struct AppAppearanceModifier: ViewModifier {
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceOption.system.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.neon.rawValue
    @AppStorage(SettingsKey.glassLevel) private var glassRaw = GlassLevel.balanced.rawValue

    func body(content: Content) -> some View {
        let theme = AppTheme(rawValue: themeRaw) ?? .neon
        return content
            .environment(\.appTheme, theme)
            .environment(\.glassLevel, GlassLevel(rawValue: glassRaw) ?? .balanced)
            .tint(theme.primary)
            .preferredColorScheme(AppearanceOption(rawValue: appearanceRaw)?.colorScheme)
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
    @Environment(\.appTheme) private var theme

    var body: some View {
        let dark = colorScheme == .dark
        LinearGradient(
            colors: dark
                ? [Color(red: 0.04, green: 0.04, blue: 0.07), Color(red: 0.08, green: 0.07, blue: 0.11)]
                : [Color(red: 0.98, green: 0.98, blue: 1.0), Color(red: 0.93, green: 0.93, blue: 0.96)],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(alignment: .top) {
            Circle()
                .fill(theme.secondary.opacity(dark ? 0.40 : 0.22))
                .frame(width: 480, height: 480)
                .blur(radius: 120)
                .offset(x: -80, y: -200)
        }
        .overlay(alignment: .center) {
            Circle()
                .fill(theme.primary.opacity(dark ? 0.22 : 0.14))
                .frame(width: 380, height: 380)
                .blur(radius: 130)
                .offset(x: 140, y: 40)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(theme.primary.opacity(dark ? 0.30 : 0.18))
                .frame(width: 420, height: 420)
                .blur(radius: 120)
                .offset(x: -120, y: 160)
        }
        .ignoresSafeArea()
    }
}

/// Fond flou fabriqué à partir de la photo affichée : les éléments en verre prennent ses couleurs.
struct PhotoBackdrop: View {
    let asset: PHAsset
    @StateObject private var loader = AssetImageLoader()
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Color.clear
            .overlay {
                if let image = loader.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 50)
                        .saturation(1.5)
                        .opacity(colorScheme == .dark ? 0.6 : 0.5)
                        .transition(.opacity)
                }
            }
            .clipped()
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .animation(.easeInOut(duration: 0.4), value: loader.image != nil)
            .onAppear { loader.load(asset, targetSize: CGSize(width: 180, height: 180)) }
            .onDisappear { loader.cancel() }
    }
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

    @Environment(\.appTheme) private var theme
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
        let colors: [Color] = [theme.primary, theme.secondary, theme.primary, .yellow, .mint, .white]
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
                color: colors.randomElement() ?? theme.primary
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
