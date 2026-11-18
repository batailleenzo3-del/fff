//
//  Models.swift
//  Les types de données de l'app.
//

import Foundation
import Photos

/// Quels médias afficher.
nonisolated enum MediaFilter: String, CaseIterable, Identifiable, Sendable {
    case all, photos, videos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return L10n.tr("Tout", "All")
        case .photos: return L10n.tr("Photos", "Photos")
        case .videos: return L10n.tr("Vidéos", "Videos")
        }
    }
}

/// Un mois précis (ex : novembre 2026).
nonisolated struct MonthKey: Hashable, Comparable, Identifiable, Sendable {
    let year: Int
    let month: Int

    var id: String { "\(year)-\(month)" }
    var title: String { L10n.monthTitle(year: year, month: month) }

    static func < (lhs: MonthKey, rhs: MonthKey) -> Bool {
        (lhs.year, lhs.month) < (rhs.year, rhs.month)
    }
}

/// Ce que l'utilisateur est en train de trier.
nonisolated enum SortSource: Hashable, Sendable {
    /// Mode normal : toute la galerie, des plus récentes aux plus anciennes.
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
    case keep, trash
}

struct HistoryEntry {
    let asset: PHAsset
    let decision: SwipeDecision
}

/// Résultats calculés en arrière-plan puis renvoyés à l'écran.
nonisolated struct AssetList: @unchecked Sendable {
    let assets: [PHAsset]
}

nonisolated struct TrashSnapshot: @unchecked Sendable {
    let assets: [PHAsset]
    let sizes: [String: Int64]
}
