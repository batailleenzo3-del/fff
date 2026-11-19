//
//  Models.swift
//  Les types de données et réglages de l'app.
//

import Foundation
import Photos
import SwiftUI

// MARK: - Réglages (clés de sauvegarde)

nonisolated enum SettingsKey {
    static let onboardingDone = "settings.onboardingDone"
    static let appearance = "settings.appearance"
    static let sortOrder = "settings.sortOrder"
    static let cycle = "settings.cycle"
    static let haptics = "settings.haptics"
    static let videoMuted = "swipe.videoMuted"
    static let reviewRequested = "settings.reviewRequested"
}

/// Ordre d'affichage des médias.
nonisolated enum SortOrder: String, CaseIterable, Identifiable, Sendable {
    case newest, oldest, largest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .newest: return L10n.t("sort_newest")
        case .oldest: return L10n.t("sort_oldest")
        case .largest: return L10n.t("sort_largest")
        }
    }

    static var current: SortOrder {
        SortOrder(rawValue: UserDefaults.standard.string(forKey: SettingsKey.sortOrder) ?? "") ?? .newest
    }
}

/// Fréquence du retour automatique aux photos les plus récentes.
nonisolated enum CycleOption: String, CaseIterable, Identifiable, Sendable {
    case day, twoDays, week, never

    var id: String { rawValue }

    var seconds: TimeInterval? {
        switch self {
        case .day: return 24 * 3600
        case .twoDays: return 48 * 3600
        case .week: return 7 * 24 * 3600
        case .never: return nil
        }
    }

    var title: String {
        switch self {
        case .day: return L10n.t("cycle_day")
        case .twoDays: return L10n.t("cycle_two_days")
        case .week: return L10n.t("cycle_week")
        case .never: return L10n.t("cycle_never")
        }
    }

    static var current: CycleOption {
        CycleOption(rawValue: UserDefaults.standard.string(forKey: SettingsKey.cycle) ?? "") ?? .day
    }
}

/// Thème clair / sombre.
nonisolated enum AppearanceOption: String, CaseIterable, Identifiable, Sendable {
    case system, light, dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return L10n.t("appearance_system")
        case .light: return L10n.t("appearance_light")
        case .dark: return L10n.t("appearance_dark")
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Médias

/// Quels médias afficher.
nonisolated enum MediaFilter: String, CaseIterable, Identifiable, Sendable {
    case all, photos, videos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.t("filter_all")
        case .photos: return L10n.t("filter_photos")
        case .videos: return L10n.t("filter_videos")
        }
    }
}

/// Un mois précis (ex : novembre 2026).
nonisolated struct MonthKey: Hashable, Comparable, Identifiable, Codable, Sendable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }
    var title: String { L10n.monthTitle(year: year, month: month) }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// Ce que l'utilisateur est en train de trier.
nonisolated enum SortSource: Hashable, Codable, Sendable {
    /// Mode normal : toute la galerie.
    case recent
    /// Un ou plusieurs albums choisis.
    case albums(ids: [String], title: String)
    /// Un mois précis.
    case month(MonthKey)
}

/// Un album de la galerie.
nonisolated struct AlbumInfo: Identifiable, Hashable, Sendable {
    let id: String
    let title: String
    let count: Int
    let isSmart: Bool
}

/// Un mois et son nombre de médias.
nonisolated struct MonthInfo: Identifiable, Hashable, Sendable {
    let key: MonthKey
    let count: Int
    var id: String { key.id }
}

enum SwipeDecision {
    case keep, trash, favorite
}

struct HistoryEntry {
    let asset: PHAsset
    let decision: SwipeDecision
}

/// Groupe de photos similaires (rafale, doublons).
nonisolated struct SimilarGroup: Identifiable, @unchecked Sendable {
    let id: String
    let assets: [PHAsset]
    /// La photo conseillée à garder.
    let bestID: String
}

/// Résultats calculés en arrière-plan puis renvoyés à l'écran.
nonisolated struct AssetList: @unchecked Sendable {
    let assets: [PHAsset]
    /// Date du média le plus récent de la source (y compris ceux déjà vus).
    let newestDate: Date?
}

nonisolated struct TrashSnapshot: @unchecked Sendable {
    let assets: [PHAsset]
    let sizes: [String: Int64]
}
