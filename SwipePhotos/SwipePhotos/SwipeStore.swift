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

    /// Nouvelles photos arrivées dans la galerie depuis le dernier chargement.
    @Published private(set) var newItemsCount = 0

    /// Médias déjà swipés pendant le cycle en cours (24 h) : ils ne sont pas reproposés.
    private var reviewed: Set<String> = []
    private var newestDate: Date?
    private var saveTask: Task<Void, Never>?

    /// Toutes les 24 h, l'app repart automatiquement des photos les plus récentes.
    static let cycleDuration: TimeInterval = 24 * 60 * 60

    private let reviewedKey = "swipe.reviewedIDs"
    private let cycleStartKey = "swipe.cycleStart"
    private let sourceKey = "swipe.source"
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
        reviewed = Set(defaults.stringArray(forKey: reviewedKey) ?? [])
        if let data = defaults.data(forKey: sourceKey),
           let saved = try? JSONDecoder().decode(SortSource.self, from: data) {
            source = saved
        }
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

    /// Vrai si le dernier "retour au début" date de plus de 24 h.
    private var cycleExpired: Bool {
        let start = UserDefaults.standard.double(forKey: cycleStartKey)
        return start == 0 || Date().timeIntervalSince1970 - start > Self.cycleDuration
    }

    /// Appelé à l'ouverture de l'app.
    /// - Moins de 24 h depuis le dernier cycle : on reprend là où on s'était arrêté
    ///   (les nouvelles photos éventuelles passent en premier).
    /// - Plus de 24 h : on repart des photos les plus récentes, y compris celles déjà gardées.
    func start() {
        loadTrash()
        if cycleExpired {
            beginNewCycle()
            source = .recent
            saveSource()
        }
        reload()
    }

    /// Quand l'app revient au premier plan : pas de rechargement, sauf si 24 h sont passées.
    func becameActive() {
        guard isAuthorized, hasLoaded else { return }
        if cycleExpired {
            start()
        } else {
            checkForNewItems()
        }
    }

    /// Bouton ↻ : retour aux photos les plus récentes de toute la galerie
    /// (on revoit tout, même ce qui a déjà été gardé).
    func refreshToNewest() {
        beginNewCycle()
        source = .recent
        saveSource()
        reload()
    }

    private func beginNewCycle() {
        reviewed.removeAll()
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: cycleStartKey)
        persistNow()
    }

    /// Recharge la pile : tout ce qui n'a pas encore été swipé pendant ce cycle,
    /// du plus récent au plus ancien.
    func reload() {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true

        let savedTrash = UserDefaults.standard.stringArray(forKey: trashKey) ?? []
        let excluded = Set(savedTrash).union(trash.map(\.localIdentifier)).union(reviewed)
        let currentSource = source
        let currentFilter = filter

        Task {
            let list = await Task.detached(priority: .userInitiated) {
                LibraryService.fetchDeck(source: currentSource, filter: currentFilter, excluded: excluded)
            }.value
            guard generation == loadGeneration else { return }
            deck = list.assets
            newestDate = list.newestDate
            index = 0
            history = []
            keptCount = 0
            newItemsCount = 0
            isLoading = false
            hasLoaded = true
        }
    }

    /// Compte les photos prises depuis le dernier chargement (sans toucher à la pile).
    func checkForNewItems() {
        guard case .recent = source, let since = newestDate else { return }
        let currentFilter = filter
        Task {
            let count = await Task.detached(priority: .utility) {
                LibraryService.countNewer(than: since, filter: currentFilter)
            }.value
            newItemsCount = count
        }
    }

    func select(source newSource: SortSource) {
        source = newSource
        saveSource()
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
        reviewed.insert(asset.localIdentifier)
        scheduleSave()
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
        reviewed.remove(last.asset.localIdentifier)
        scheduleSave()
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

    /// Enregistre la progression (appelé aussi quand l'app passe en arrière-plan).
    func persistNow() {
        saveTask?.cancel()
        UserDefaults.standard.set(Array(reviewed), forKey: reviewedKey)
    }

    /// Enregistre la progression 1 s après le dernier swipe (évite d'écrire à chaque geste).
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            UserDefaults.standard.set(Array(reviewed), forKey: reviewedKey)
        }
    }

    private func saveSource() {
        if let data = try? JSONEncoder().encode(source) {
            UserDefaults.standard.set(data, forKey: sourceKey)
        }
    }

    private func saveTrash() {
        UserDefaults.standard.set(trash.map(\.localIdentifier), forKey: trashKey)
    }
}
