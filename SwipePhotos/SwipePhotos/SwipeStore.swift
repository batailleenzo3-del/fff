//
//  SwipeStore.swift
//  Le "cerveau" de l'app : la pile de médias, la corbeille, l'annulation,
//  les doublons, les statistiques.
//

import SwiftUI
import Combine
import Photos
import PhotosUI
import UIKit

@MainActor
final class SwipeStore: ObservableObject {

    // MARK: État affiché

    @Published var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)

    /// Médias à trier.
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

    /// Nouvelles photos arrivées dans la galerie depuis le dernier chargement.
    @Published private(set) var newItemsCount = 0

    /// Doublons / photos similaires (nil = pas encore analysé).
    @Published private(set) var similarGroups: [SimilarGroup]?
    /// Progression de l'analyse des doublons (nil = pas d'analyse en cours).
    @Published private(set) var similarProgress: Double?

    /// Déclencheurs d'effets (confettis, vibrations).
    @Published private(set) var celebrateTrigger = 0
    @Published private(set) var decisionCount = 0
    @Published private(set) var lastDecision: SwipeDecision?

    // MARK: Statistiques

    @Published private(set) var keptCount = 0
    @Published private(set) var totalFreedBytes: Int64 = 0
    @Published private(set) var totalDeletedCount = 0
    @Published private(set) var totalSwiped = 0
    @Published private(set) var totalKept = 0
    @Published private(set) var totalFavorited = 0

    // MARK: Freemium (swipes gratuits)

    /// Nombre de swipes gratuits déjà utilisés (sauvegardé, ne diminue jamais).
    @Published private(set) var freeSwipesUsed = 0
    /// Médias déjà comptés : re-swiper une photo après « Annuler » ne coûte rien de plus,
    /// et « Annuler » ne rend pas de swipe → impossible de contourner la limite.
    private var countedSwipeIDs: Set<String> = []

    // MARK: Interne

    /// Médias déjà swipés pendant le cycle en cours : ils ne sont pas reproposés.
    private var reviewed: Set<String> = []
    private var newestDate: Date?
    private var saveTask: Task<Void, Never>?
    private var changeTask: Task<Void, Never>?
    private var similarTask: Task<Void, Never>?
    private var observer: LibraryObserver?
    private var reloadAfterLimitedPicker = false
    private var loadGeneration = 0

    private enum Key {
        static let reviewed = "swipe.reviewedIDs"
        static let cycleStart = "swipe.cycleStart"
        static let source = "swipe.source"
        static let trash = "swipe.trashIDs"
        static let filter = "swipe.mediaFilter"
        static let freed = "swipe.totalFreedBytes"
        static let deleted = "swipe.totalDeletedCount"
        static let swiped = "stats.totalSwiped"
        static let kept = "stats.totalKept"
        static let favorited = "stats.totalFavorited"
        static let freeSwipesUsed = "freemium.swipesUsed"
        static let countedSwipeIDs = "freemium.countedIDs"
    }

    init() {
        let defaults = UserDefaults.standard
        totalFreedBytes = Int64(defaults.integer(forKey: Key.freed))
        totalDeletedCount = defaults.integer(forKey: Key.deleted)
        totalSwiped = defaults.integer(forKey: Key.swiped)
        totalKept = defaults.integer(forKey: Key.kept)
        totalFavorited = defaults.integer(forKey: Key.favorited)
        freeSwipesUsed = defaults.integer(forKey: Key.freeSwipesUsed)
        countedSwipeIDs = Set(defaults.stringArray(forKey: Key.countedSwipeIDs) ?? [])
        filter = MediaFilter(rawValue: defaults.string(forKey: Key.filter) ?? "") ?? .all
        reviewed = Set(defaults.stringArray(forKey: Key.reviewed) ?? [])
        if let data = defaults.data(forKey: Key.source),
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
    var reviewedCount: Int { reviewed.count }
    var freeSwipesLeft: Int { max(AppConfig.freeSwipeLimit - freeSwipesUsed, 0) }

    /// Vrai si la limite gratuite est atteinte pour la carte affichée.
    func isSwipeLocked(isPro: Bool) -> Bool {
        guard !isPro, let asset = current else { return false }
        if countedSwipeIDs.contains(asset.localIdentifier) { return false } // déjà payée avant un « Annuler »
        return freeSwipesUsed >= AppConfig.freeSwipeLimit
    }

    var sourceTitle: String {
        switch source {
        case .recent: return loc("source_recent")
        case .albums(_, let title): return title
        case .month(let key): return key.title
        }
    }

    // MARK: Démarrage et cycle

    func requestAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if isAuthorized { start() }
    }

    /// Vrai si le dernier "retour au début" est plus ancien que la durée choisie dans les Réglages.
    private var cycleExpired: Bool {
        let start = UserDefaults.standard.double(forKey: Key.cycleStart)
        if start == 0 { return true }
        guard let duration = CycleOption.current.seconds else { return false }
        return Date().timeIntervalSince1970 - start > duration
    }

    /// Appelé à l'ouverture de l'app : on reprend là où on s'était arrêté,
    /// sauf si le cycle est terminé (retour aux photos les plus récentes).
    func start() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        startObservingLibrary()
        loadTrash()
        if cycleExpired {
            beginNewCycle()
            source = .recent
            saveSource()
        }
        reload()
    }

    /// Quand l'app revient au premier plan : pas de rechargement, sauf si le cycle est terminé.
    func becameActive() {
        authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)
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
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Key.cycleStart)
        persistNow()
    }

    /// Recharge la pile : tout ce qui n'a pas encore été swipé pendant ce cycle.
    func reload() {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true

        let savedTrash = UserDefaults.standard.stringArray(forKey: Key.trash) ?? []
        let excluded = Set(savedTrash).union(trash.map(\.localIdentifier)).union(reviewed)
        let currentSource = source
        let currentFilter = filter
        let order = SortOrder.current

        Task {
            let list = await Task.detached(priority: .userInitiated) {
                LibraryService.fetchDeck(source: currentSource, filter: currentFilter, order: order, excluded: excluded)
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

    func select(source newSource: SortSource) {
        source = newSource
        saveSource()
        reload()
    }

    func select(filter newFilter: MediaFilter) {
        guard newFilter != filter else { return }
        filter = newFilter
        UserDefaults.standard.set(newFilter.rawValue, forKey: Key.filter)
        reload()
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

    // MARK: Accès limité aux photos

    /// Ouvre l'écran iOS pour choisir les photos accessibles (mode « accès limité »).
    func presentLimitedPicker() {
        guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }),
              var controller = scene.keyWindow?.rootViewController else { return }
        while let presented = controller.presentedViewController {
            controller = presented
        }
        reloadAfterLimitedPicker = true
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
    }

    // MARK: Swipe

    func decide(_ decision: SwipeDecision) {
        guard let asset = current else { return }
        history.append(HistoryEntry(asset: asset, decision: decision))
        reviewed.insert(asset.localIdentifier)
        scheduleSave()
        totalSwiped += 1
        countFreeSwipe(asset.localIdentifier)

        switch decision {
        case .trash:
            trash.append(asset)
            trashSizes[asset.localIdentifier] = LibraryService.fileSize(of: asset)
            saveTrash()
        case .keep:
            keptCount += 1
            totalKept += 1
        case .favorite:
            keptCount += 1
            totalKept += 1
            totalFavorited += 1
            let id = asset.localIdentifier
            Task { try? await LibraryService.setFavorite(id: id, true) }
        }
        saveStats()

        index += 1
        lastDecision = decision
        decisionCount += 1
        if index == deck.count && !deck.isEmpty {
            celebrateTrigger += 1
        }
    }

    func undo() {
        guard let last = history.popLast() else { return }
        let id = last.asset.localIdentifier
        reviewed.remove(id)
        scheduleSave()
        totalSwiped = max(totalSwiped - 1, 0)

        switch last.decision {
        case .trash:
            trash.removeAll { $0.localIdentifier == id }
            trashSizes[id] = nil
            saveTrash()
        case .keep:
            keptCount = max(keptCount - 1, 0)
            totalKept = max(totalKept - 1, 0)
        case .favorite:
            keptCount = max(keptCount - 1, 0)
            totalKept = max(totalKept - 1, 0)
            totalFavorited = max(totalFavorited - 1, 0)
            let wasFavorite = last.asset.isFavorite
            Task { try? await LibraryService.setFavorite(id: id, wasFavorite) }
        }
        saveStats()
        index = max(index - 1, 0)
    }

    // MARK: Corbeille

    /// Ajoute des médias à la corbeille (utilisé par l'écran Doublons).
    func addToTrash(_ assets: [PHAsset]) {
        let existing = Set(trash.map(\.localIdentifier))
        let newOnes = assets.filter { !existing.contains($0.localIdentifier) }
        guard !newOnes.isEmpty else { return }
        trash.append(contentsOf: newOnes)
        for asset in newOnes {
            trashSizes[asset.localIdentifier] = LibraryService.fileSize(of: asset)
        }
        // On les retire aussi de la pile à venir
        removeUpcoming(Set(newOnes.map(\.localIdentifier)))
        saveTrash()
    }

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

    /// Compte un swipe gratuit (une seule fois par média, et jamais rendu par « Annuler »).
    private func countFreeSwipe(_ id: String) {
        guard freeSwipesUsed < AppConfig.freeSwipeLimit, countedSwipeIDs.insert(id).inserted else { return }
        freeSwipesUsed += 1
        UserDefaults.standard.set(freeSwipesUsed, forKey: Key.freeSwipesUsed)
        UserDefaults.standard.set(Array(countedSwipeIDs), forKey: Key.countedSwipeIDs)
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
        removeFromSimilarGroups(Set(ids))

        totalFreedBytes += bytes
        totalDeletedCount += ids.count
        saveStats()
        celebrateTrigger += 1
        return (ids.count, bytes)
    }

    // MARK: Doublons et photos similaires

    func scanSimilar(force: Bool = false) {
        if !force && (similarGroups != nil || similarProgress != nil) { return }
        similarTask?.cancel()
        similarGroups = nil
        similarProgress = 0

        let excluded = Set(trash.map(\.localIdentifier))
        let progressHandler: @Sendable (Double) -> Void = { [weak self] value in
            Task { @MainActor [weak self] in
                guard let self, self.similarProgress != nil else { return }
                self.similarProgress = value
            }
        }
        similarTask = Task {
            let worker = Task.detached(priority: .userInitiated) {
                SimilarityService.findGroups(excluded: excluded, progress: progressHandler)
            }
            let groups = await withTaskCancellationHandler {
                await worker.value
            } onCancel: {
                worker.cancel()
            }
            guard !Task.isCancelled else { return }
            similarGroups = groups
            similarProgress = nil
        }
    }

    /// Met à la corbeille les photos choisies d'un groupe, et retire le groupe de la liste.
    func resolveGroup(_ group: SimilarGroup, trashIDs: Set<String>) {
        addToTrash(group.assets.filter { trashIDs.contains($0.localIdentifier) })
        dismissGroup(group)
    }

    /// "Tout garder" : on retire simplement le groupe de la liste.
    func dismissGroup(_ group: SimilarGroup) {
        similarGroups?.removeAll { $0.id == group.id }
    }

    private func removeFromSimilarGroups(_ deleted: Set<String>) {
        guard let groups = similarGroups else { return }
        var updated: [SimilarGroup] = []
        for group in groups {
            let left = group.assets.filter { !deleted.contains($0.localIdentifier) }
            guard left.count > 1 else { continue }
            let bestStillThere = left.contains { $0.localIdentifier == group.bestID }
            updated.append(SimilarGroup(id: group.id, assets: left,
                                        bestID: bestStillThere ? group.bestID : left[0].localIdentifier))
        }
        similarGroups = updated
    }

    // MARK: Changements dans la galerie

    private func startObservingLibrary() {
        guard observer == nil, isAuthorized else { return }
        observer = LibraryObserver { [weak self] in
            Task { @MainActor [weak self] in
                self?.libraryChanged()
            }
        }
    }

    /// Une photo a été ajoutée ou supprimée ailleurs (app Photos, iCloud…) : on met à jour.
    private func libraryChanged() {
        changeTask?.cancel()
        changeTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            authorization = PHPhotoLibrary.authorizationStatus(for: .readWrite)

            if reloadAfterLimitedPicker {
                reloadAfterLimitedPicker = false
                reload()
                return
            }

            let upcomingIDs: [String] = index < deck.count
                ? deck[index..<min(index + 40, deck.count)].map(\.localIdentifier)
                : []
            let ids = trash.map(\.localIdentifier) + upcomingIDs
            if !ids.isEmpty {
                let existing = await Task.detached(priority: .utility) {
                    LibraryService.existingIDs(ids)
                }.value
                let missing = Set(ids).subtracting(existing)
                if !missing.isEmpty {
                    trash.removeAll { missing.contains($0.localIdentifier) }
                    for id in missing { trashSizes[id] = nil }
                    removeUpcoming(missing)
                    removeFromSimilarGroups(missing)
                    saveTrash()
                }
            }
            checkForNewItems()
        }
    }

    private func removeUpcoming(_ ids: Set<String>) {
        guard index < deck.count else { return }
        let kept = deck[index...].filter { !ids.contains($0.localIdentifier) }
        deck = Array(deck[..<index]) + kept
    }

    // MARK: Sauvegarde

    /// Enregistre la progression (appelé aussi quand l'app passe en arrière-plan).
    func persistNow() {
        saveTask?.cancel()
        UserDefaults.standard.set(Array(reviewed), forKey: Key.reviewed)
    }

    /// Enregistre la progression 1 s après le dernier swipe (évite d'écrire à chaque geste).
    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            UserDefaults.standard.set(Array(reviewed), forKey: Key.reviewed)
        }
    }

    private func saveSource() {
        if let data = try? JSONEncoder().encode(source) {
            UserDefaults.standard.set(data, forKey: Key.source)
        }
    }

    private func saveStats() {
        let defaults = UserDefaults.standard
        defaults.set(Int(totalFreedBytes), forKey: Key.freed)
        defaults.set(totalDeletedCount, forKey: Key.deleted)
        defaults.set(totalSwiped, forKey: Key.swiped)
        defaults.set(totalKept, forKey: Key.kept)
        defaults.set(totalFavorited, forKey: Key.favorited)
    }

    private func loadTrash() {
        let ids = UserDefaults.standard.stringArray(forKey: Key.trash) ?? []
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
        UserDefaults.standard.set(trash.map(\.localIdentifier), forKey: Key.trash)
    }
}
