//
//  LibraryService.swift
//  Tout ce qui lit ou modifie la photothèque (PhotoKit).
//  Ces fonctions tournent en arrière-plan pour que l'app ne fige jamais.
//

import Foundation
import Photos

nonisolated enum LibraryService {

    // MARK: Options de recherche

    static func fetchOptions(filter: MediaFilter) -> PHFetchOptions {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        let image = PHAssetMediaType.image.rawValue
        let video = PHAssetMediaType.video.rawValue
        switch filter {
        case .all:
            options.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d", image, video)
        case .photos:
            options.predicate = NSPredicate(format: "mediaType == %d", image)
        case .videos:
            options.predicate = NSPredicate(format: "mediaType == %d", video)
        }
        return options
    }

    // MARK: Médias à trier

    /// Renvoie les médias à trier, du plus récent au plus ancien.
    /// `excluded` : identifiants à ne pas montrer (ceux déjà dans la corbeille).
    static func fetchDeck(source: SortSource, filter: MediaFilter, excluded: Set<String>) -> AssetList {
        var result: [PHAsset] = []

        switch source {
        case .recent:
            let fetch = PHAsset.fetchAssets(with: fetchOptions(filter: filter))
            result.reserveCapacity(fetch.count)
            fetch.enumerateObjects { asset, _, _ in
                if !excluded.contains(asset.localIdentifier) { result.append(asset) }
            }

        case .month(let key):
            let options = fetchOptions(filter: filter)
            var components = DateComponents()
            components.year = key.year
            components.month = key.month
            components.day = 1
            let calendar = Calendar.current
            if let start = calendar.date(from: components),
               let end = calendar.date(byAdding: .month, value: 1, to: start) {
                let datePredicate = NSPredicate(format: "creationDate >= %@ AND creationDate < %@",
                                                start as NSDate, end as NSDate)
                let predicates = [options.predicate, datePredicate].compactMap { $0 }
                options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            }
            let fetch = PHAsset.fetchAssets(with: options)
            fetch.enumerateObjects { asset, _, _ in
                if !excluded.contains(asset.localIdentifier) { result.append(asset) }
            }

        case .albums(let ids, _):
            let collections = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: ids, options: nil)
            let options = fetchOptions(filter: filter)
            var seen = Set<String>()
            collections.enumerateObjects { collection, _, _ in
                let fetch = PHAsset.fetchAssets(in: collection, options: options)
                fetch.enumerateObjects { asset, _, _ in
                    let id = asset.localIdentifier
                    if !excluded.contains(id) && seen.insert(id).inserted {
                        result.append(asset)
                    }
                }
            }
            result.sort { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
        }

        return AssetList(assets: result)
    }

    // MARK: Albums et mois

    /// Albums intelligents utiles (favoris, captures d'écran…) + albums créés par l'utilisateur.
    static func fetchAlbums() -> [AlbumInfo] {
        let countOptions = fetchOptions(filter: .all)
        var smart: [AlbumInfo] = []
        var user: [AlbumInfo] = []

        let smartTypes: [PHAssetCollectionSubtype] = [
            .smartAlbumFavorites,
            .smartAlbumScreenshots,
            .smartAlbumSelfPortraits,
            .smartAlbumLivePhotos,
            .smartAlbumVideos,
            .smartAlbumDepthEffect,
            .smartAlbumPanoramas,
            .smartAlbumBursts,
            .smartAlbumSlomoVideos,
            .smartAlbumTimelapses
        ]
        for type in smartTypes {
            let collections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: type, options: nil)
            collections.enumerateObjects { collection, _, _ in
                let count = PHAsset.fetchAssets(in: collection, options: countOptions).count
                if count > 0 {
                    smart.append(AlbumInfo(id: collection.localIdentifier,
                                           title: collection.localizedTitle ?? "—",
                                           count: count,
                                           isSmart: true))
                }
            }
        }

        // Albums créés sur l'iPhone (y compris ceux rangés dans des dossiers)
        let userCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: nil)
        userCollections.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: countOptions).count
            if count > 0 {
                user.append(AlbumInfo(id: collection.localIdentifier,
                                      title: collection.localizedTitle ?? "—",
                                      count: count,
                                      isSmart: false))
            }
        }
        user.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        return smart + user
    }

    /// Liste des mois qui contiennent des médias, du plus récent au plus ancien.
    static func fetchMonths(filter: MediaFilter) -> [MonthInfo] {
        let fetch = PHAsset.fetchAssets(with: fetchOptions(filter: filter))
        let calendar = Calendar.current
        var counts: [MonthKey: Int] = [:]
        fetch.enumerateObjects { asset, _, _ in
            guard let date = asset.creationDate else { return }
            let components = calendar.dateComponents([.year, .month], from: date)
            guard let year = components.year, let month = components.month else { return }
            counts[MonthKey(year: year, month: month), default: 0] += 1
        }
        return counts
            .map { MonthInfo(key: $0.key, count: $0.value) }
            .sorted { $0.key > $1.key }
    }

    // MARK: Corbeille

    /// Retrouve des médias à partir de leurs identifiants (dans le même ordre).
    static func fetchAssets(ids: [String]) -> [PHAsset] {
        guard !ids.isEmpty else { return [] }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        fetch.enumerateObjects { asset, _, _ in assets.append(asset) }
        let order = Dictionary(ids.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        assets.sort { (order[$0.localIdentifier] ?? 0) < (order[$1.localIdentifier] ?? 0) }
        return assets
    }

    /// Taille d'un média sur l'iPhone (photo + vidéo Live Photo, etc.).
    static func fileSize(of asset: PHAsset) -> Int64 {
        var total: Int64 = 0
        for resource in PHAssetResource.assetResources(for: asset) {
            if let size = resource.value(forKey: "fileSize") as? Int64 {
                total += size
            } else if let size = resource.value(forKey: "fileSize") as? Int {
                total += Int64(size)
            }
        }
        return total
    }

    static func sizes(for assets: [PHAsset]) -> [String: Int64] {
        var sizes: [String: Int64] = [:]
        for asset in assets {
            sizes[asset.localIdentifier] = fileSize(of: asset)
        }
        return sizes
    }

    /// Supprime les médias en UNE seule fois → une seule pop-up de confirmation iOS.
    static func delete(ids: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }
}
