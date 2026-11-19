//
//  SimilarityService.swift
//  Détection des photos similaires et des doublons (rafales, photos prises en série).
//
//  Principe : on ne compare que les photos prises à quelques secondes d'intervalle,
//  avec l'intelligence artificielle d'Apple (Vision), directement sur l'iPhone.
//

import Foundation
import Photos
import Vision
import UIKit

/// Petite boîte pour récupérer l'image renvoyée par PhotoKit.
nonisolated final class ImageBox: @unchecked Sendable {
    var cgImage: CGImage?
}

nonisolated enum SimilarityService {

    /// Cherche les groupes de photos similaires (du plus récent au plus ancien).
    /// `progress` est appelé régulièrement avec une valeur entre 0 et 1.
    static func findGroups(excluded: Set<String>, progress: @escaping @Sendable (Double) -> Void) -> [SimilarGroup] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let fetch = PHAsset.fetchAssets(with: options)

        var assets: [PHAsset] = []
        assets.reserveCapacity(fetch.count)
        fetch.enumerateObjects { asset, _, _ in
            if !excluded.contains(asset.localIdentifier) { assets.append(asset) }
        }

        // 1. On regroupe les photos prises à moins de `burstWindow` secondes d'intervalle
        var clusters: [[PHAsset]] = []
        var currentCluster: [PHAsset] = []
        var lastDate: Date?
        for asset in assets {
            guard let date = asset.creationDate else { continue }
            if let last = lastDate, date.timeIntervalSince(last) <= AppConfig.burstWindow {
                currentCluster.append(asset)
            } else {
                if currentCluster.count > 1 { clusters.append(currentCluster) }
                currentCluster = [asset]
            }
            lastDate = date
        }
        if currentCluster.count > 1 { clusters.append(currentCluster) }

        // 2. Dans chaque série, on compare les photos voisines
        let total = max(clusters.reduce(0) { $0 + $1.count }, 1)
        var processed = 0
        var groups: [SimilarGroup] = []

        let imageOptions = PHImageRequestOptions()
        imageOptions.isSynchronous = true
        imageOptions.deliveryMode = .highQualityFormat
        imageOptions.resizeMode = .fast
        imageOptions.isNetworkAccessAllowed = false

        progress(0)
        for cluster in clusters {
            if Task.isCancelled { break }

            var prints: [VNFeaturePrintObservation?] = []
            for asset in cluster {
                prints.append(featurePrint(for: asset, options: imageOptions))
                processed += 1
                if processed % 8 == 0 { progress(Double(processed) / Double(total)) }
            }

            var current: [PHAsset] = [cluster[0]]
            for i in 1..<cluster.count {
                if isSimilar(cluster[i - 1], cluster[i], prints[i - 1], prints[i]) {
                    current.append(cluster[i])
                } else {
                    if current.count > 1 { groups.append(makeGroup(current)) }
                    current = [cluster[i]]
                }
            }
            if current.count > 1 { groups.append(makeGroup(current)) }
        }
        progress(1)
        return Array(groups.reversed())
    }

    // MARK: Détails

    private static func featurePrint(for asset: PHAsset, options: PHImageRequestOptions) -> VNFeaturePrintObservation? {
        let box = ImageBox()
        PHImageManager.default().requestImage(
            for: asset, targetSize: CGSize(width: 320, height: 320), contentMode: .aspectFit, options: options
        ) { image, _ in
            box.cgImage = image?.cgImage
        }
        guard let cgImage = box.cgImage else { return nil }

        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    private static func isSimilar(_ a: PHAsset, _ b: PHAsset,
                                  _ printA: VNFeaturePrintObservation?, _ printB: VNFeaturePrintObservation?) -> Bool {
        // Doublon exact : même taille et pris à la même seconde
        if a.pixelWidth == b.pixelWidth, a.pixelHeight == b.pixelHeight,
           let dateA = a.creationDate, let dateB = b.creationDate,
           abs(dateA.timeIntervalSince(dateB)) < 1 {
            return true
        }
        guard let printA, let printB else { return false }
        var distance: Float = 0
        do {
            try printA.computeDistance(&distance, to: printB)
        } catch {
            return false
        }
        return distance <= AppConfig.similarityThreshold
    }

    private static func makeGroup(_ assets: [PHAsset]) -> SimilarGroup {
        let best = assets.max { score($0) < score($1) } ?? assets[0]
        return SimilarGroup(id: assets[0].localIdentifier, assets: assets, bestID: best.localIdentifier)
    }

    /// La « meilleure » photo : favorite d'abord, puis la plus grande résolution, puis la plus récente.
    private static func score(_ asset: PHAsset) -> Double {
        let favorite = asset.isFavorite ? 1e13 : 0
        let pixels = Double(asset.pixelWidth) * Double(asset.pixelHeight)
        let recency = (asset.creationDate?.timeIntervalSince1970 ?? 0) / 1e10
        return favorite + pixels + recency
    }
}
