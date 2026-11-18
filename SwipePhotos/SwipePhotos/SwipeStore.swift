//
//  SwipeStore.swift
//  Le "cerveau" de l'app : la pile de médias, la corbeille, l'annulation, les stats.
//

import SwiftUI
import Combine
import Photos

@MainActor
final class SwipeStore: ObservableObject {

    // MARK: État

    @Published var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    /// Médias à trier (du plus récent au plus ancien).
    @Published private(set) var deck: [PHAsset] = []
    /// Position actuelle dans la pile.
    @Published private(set) var index = 0
    /// Médias mis à la corbeille (pas encore supprimés).
    @Published private(set) var trash: [PHAsset] = []
    @Published private(set) var trashSizes: [String: Int64] = [:]
    @Published private(set) var history: [HistoryEntry] = []

    @Published private(set) var source: SortSource = .recent
    @Published private(set) var filter: MediaFilter = .all

    @Published private(set) var isLoading = false
    @Published private(set) var hasLoaded = false

    /// Stats de la session en cours.
    @Published private(set) var keptCount = 0
    /// Stats depuis l'installation.
    @Published private(set) var totalFreedBytes: Int64 = 0
    @Published private(set) var totalDeletedCount = 0

    private let trashKey = "swipe.trashIDs"
    private let filterKey = "swipe.mediaFilter"
    private let freedKey = "swipe.totalFreedBytes"
    private let deletedKey = "swipe.totalDeletedCount"
    private var loadGeneration = 0

    init() {
        let defaults = UserDefaults.standard
        totalFreedBytes = Int64(defaults.integer(forKey: freedKey))
        totalDeletedCount = defaults.integer(forKey: deletedKey)
        filter = MediaFilter(rawValue: defaults.string(forKey: filterKey) ?? "") ?? .all
    }

    // MARK: Infos calculées

    var isAuthorized: Bool { authorization == .authorized || authorization == .limited }
    var current: PHAsset? { index < deck.count ? deck[index] : nil }
    var upcoming: [PHAsset] { index < deck.count ? Array(deck[index..<min(index + 3, deck.count)]) : [] }
    var remaining: Int { max(deck.count - index, 0) }
    var canUndo: Bool { !history.isEmpty }
    var trashBytes: Int64 { trash.reduce(0) { $0 + (trashSizes[$1.localIdentifier] ?? 0) } }

    var sourceTitle: String {
        switch source {
        case .recent: return tr("Récentes", "Recents")
        case .albums(_, let title): return title
        case .month(let key): return key.title
        }
    }

    // MARK: Démarrage

    func requestAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if isAuthorized { start() }
    }

    /// Appelé à l'ouverture de l'app : on repart TOUJOURS des photos les plus récentes.
    func start() {
        source = .recent
        loadTrash()
        reload()
    }

    /// Recharge la pile depuis le début pour la source et le filtre actuels.
    func reload() {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true

        let savedTrash = UserDefaults.standard.stringArray(forKey: trashKey) ?? []
        let excluded = Set(savedTrash).union(trash.map(\.localIdentifier))
        let currentSource = source
        let currentFilter = filter

        Task {
            let list = await Task.detached(priority: .userInitiated) {
                LibraryService.fetchDeck(source: currentSource, filter: currentFilter, excluded: excluded)
            }.value
            guard generation == loadGeneration else { return }
            deck = list.assets
            index = 0
            history = []
            keptCount = 0
            isLoading = false
            hasLoaded = true
        }
    }

    func select(source newSource: SortSource) {
        source = newSource
        reload()
    }

    func select(filter newFilter: MediaFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        UserDefaults.standard.set(newFilter.rawValue, forKey: filterKey)
        reload()
    }

    // MARK: Swipe

    func decide(_ decision: SwipeDecision) {
        guard let asset = current else { return }
        history.append(HistoryEntry(asset: asset, decision: decision))
        switch decision {
        case .trash:
            trash.append(asset)
            trashSizes[asset.localIdentifier] = LibraryService.fileSize(of: asset)
            saveTrash()
        case .keep:
            keptCount += 1
        }
        index += 1
    }

    func undo() {
        guard let last = history.popLast() else { return }
        switch last.decision {
        case .trash:
            let id = last.asset.localIdentifier
            trash.removeAll { $0.localIdentifier == id }
            trashSizes[id] = nil
            saveTrash()
        case .keep:
            keptCount = max(keptCount - 1, 0)
        }
        index = max(index - 1, 0)
    }

    // MARK: Corbeille

    /// Sort un média de la corbeille (il est gardé).
    func restore(_ asset: PHAsset) {
        let id = asset.localIdentifier
        trash.removeAll { $0.localIdentifier == id }
        trashSizes[id] = nil
        saveTrash()
    }

    func restoreAll() {
        trash.removeAll()
        trashSizes.removeAll()
        saveTrash()
    }

    /// Supprime toute la corbeille d'un coup (une seule confirmation iOS).
    /// Renvoie le nombre de médias supprimés et l'espace libéré, ou nil si annulé.
    func emptyTrash() async -> (count: Int, bytes: Int64)? {
        let ids = trash.map(\.localIdentifier)
        guard !ids.isEmpty else { return nil }
        let bytes = trashBytes
        do {
            try await LibraryService.delete(ids: ids)
        } catch {
            return nil // l'utilisateur a refusé, ou erreur
        }
        trash.removeAll()
        trashSizes.removeAll()
        history.removeAll() // impossible d'annuler une suppression
        saveTrash()

        totalFreedBytes += bytes
        totalDeletedCount += ids.count
        UserDefaults.standard.set(Int(totalFreedBytes), forKey: freedKey)
        UserDefaults.standard.set(totalDeletedCount, forKey: deletedKey)
        return (ids.count, bytes)
    }

    private func loadTrash() {
        let ids = UserDefaults.standard.stringArray(forKey: trashKey) ?? []
        guard !ids.isEmpty else { return }
        Task {
            let snapshot = await Task.detached(priority: .utility) {
                let assets = LibraryService.fetchAssets(ids: ids)
                return TrashSnapshot(assets: assets, sizes: LibraryService.sizes(for: assets))
            }.value
            // Garde aussi ce qui a pu être ajouté pendant le chargement
            let known = Set(snapshot.assets.map(\.localIdentifier))
            let addedMeanwhile = trash.filter { !known.contains($0.localIdentifier) }
            trash = snapshot.assets + addedMeanwhile
            trashSizes.merge(snapshot.sizes) { current, _ in current }
            saveTrash()
        }
    }

    private func saveTrash() {
        UserDefaults.standard.set(trash.map(\.localIdentifier), forKey: trashKey)
    }
}
