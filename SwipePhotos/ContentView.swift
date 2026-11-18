//
//  ContentView.swift
//  SwipePhotos — trie ta galerie façon Tinder
//
//  ➜ Droite  : garder
//  ➜ Gauche  : corbeille temporaire (rien n'est supprimé tout de suite)
//  ➜ Bouton corbeille en haut : tout supprimer en UNE seule confirmation iOS
//
//  Permission requise dans Xcode (onglet Info de la cible) :
//  "Privacy - Photo Library Usage Description" (NSPhotoLibraryUsageDescription)
//

import SwiftUI
import Combine
import Photos
import UIKit

// MARK: - Modèle

enum SwipeDecision {
    case keep, trash
}

struct HistoryEntry {
    let asset: PHAsset
    let decision: SwipeDecision
}

@MainActor
final class PhotoSwipeStore: ObservableObject {
    @Published var authorization: PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    @Published private(set) var queue: [PHAsset] = []
    @Published private(set) var index = 0
    @Published private(set) var trash: [PHAsset] = []
    @Published private(set) var history: [HistoryEntry] = []
    @Published private(set) var hasLoaded = false

    private let reviewedKey = "swipe.reviewedIDs"
    private let trashKey = "swipe.trashIDs"
    private var reviewed: Set<String>

    init() {
        reviewed = Set(UserDefaults.standard.stringArray(forKey: reviewedKey) ?? [])
    }

    var isAuthorized: Bool { authorization == .authorized || authorization == .limited }
    var current: PHAsset? { index < queue.count ? queue[index] : nil }
    var upcoming: [PHAsset] { index < queue.count ? Array(queue[index..<min(index + 3, queue.count)]) : [] }
    var remaining: Int { max(queue.count - index, 0) }
    var canUndo: Bool { !history.isEmpty }

    func requestAccess() async {
        authorization = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        if isAuthorized { load() }
    }

    /// Charge toutes les photos, de la plus récente à la plus ancienne.
    func load() {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let result = PHAsset.fetchAssets(with: options)

        var all: [PHAsset] = []
        all.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in all.append(asset) }

        let existing = Set(all.map(\.localIdentifier))
        reviewed.formIntersection(existing)
        let trashIDs = Set(UserDefaults.standard.stringArray(forKey: trashKey) ?? [])
        trash = all.filter { trashIDs.contains($0.localIdentifier) }
        queue = all.filter { !reviewed.contains($0.localIdentifier) }
        index = 0
        history = []
        hasLoaded = true
        save()
    }

    func decide(_ decision: SwipeDecision) {
        guard let asset = current else { return }
        history.append(HistoryEntry(asset: asset, decision: decision))
        reviewed.insert(asset.localIdentifier)
        if decision == .trash { trash.append(asset) }
        index += 1
        save()
    }

    func undo() {
        guard let last = history.popLast() else { return }
        reviewed.remove(last.asset.localIdentifier)
        trash.removeAll { $0.localIdentifier == last.asset.localIdentifier }
        index = max(index - 1, 0)
        save()
    }

    /// Retire une photo de la corbeille (elle est alors considérée comme gardée).
    func restore(_ asset: PHAsset) {
        trash.removeAll { $0.localIdentifier == asset.localIdentifier }
        save()
    }

    /// Supprime toute la corbeille d'un coup → une seule pop-up iOS.
    @discardableResult
    func emptyTrash() async -> Int {
        let ids = trash.map(\.localIdentifier)
        guard !ids.isEmpty else { return 0 }
        do {
            try await Self.deleteAssets(ids: ids)
            trash.removeAll()
            history.removeAll() // on ne peut pas "annuler" une photo supprimée
            save()
            return ids.count
        } catch {
            return 0 // l'utilisateur a refusé la pop-up, ou erreur
        }
    }

    /// Repart de zéro : toutes les photos restantes sont reproposées.
    func resetProgress() {
        reviewed.removeAll()
        load()
    }

    nonisolated private static func deleteAssets(ids: [String]) async throws {
        try await PHPhotoLibrary.shared().performChanges {
            let assets = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
            PHAssetChangeRequest.deleteAssets(assets)
        }
    }

    private func save() {
        UserDefaults.standard.set(Array(reviewed), forKey: reviewedKey)
        UserDefaults.standard.set(trash.map(\.localIdentifier), forKey: trashKey)
    }
}

// MARK: - Chargement d'image

@MainActor
final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var requestID: PHImageRequestID?

    func load(_ asset: PHAsset, targetSize: CGSize, fast: Bool = false) {
        guard requestID == nil else { return }
        requestID = Self.request(asset, targetSize: targetSize, fast: fast) { [weak self] img in
            Task { @MainActor in
                if let img { self?.image = img }
            }
        }
    }

    func cancel() {
        if let requestID { PHImageManager.default().cancelImageRequest(requestID) }
        requestID = nil
    }

    nonisolated private static func request(
        _ asset: PHAsset,
        targetSize: CGSize,
        fast: Bool,
        completion: @escaping @Sendable (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = fast ? .fastFormat : .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true // photos iCloud
        return PHImageManager.default().requestImage(
            for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options
        ) { image, _ in
            completion(image)
        }
    }
}

// MARK: - Carte photo

struct PhotoCard: View {
    let asset: PHAsset
    @StateObject private var loader = AssetImageLoader()
    @Environment(\.displayScale) private var scale

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(white: 0.1)
                if let img = loader.image {
                    // Fond flou + photo entière par-dessus
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 30)
                        .opacity(0.6)
                        .clipped()
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ProgressView().tint(.white)
                }

                VStack {
                    Spacer()
                    HStack {
                        if let date = asset.creationDate {
                            Label(date.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        Spacer()
                        if asset.isFavorite {
                            Image(systemName: "heart.fill").foregroundStyle(.pink)
                        }
                    }
                    .padding(16)
                    .background(
                        LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                    )
                }
            }
            .onAppear {
                loader.load(asset, targetSize: CGSize(width: geo.size.width * scale, height: geo.size.height * scale))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
    }
}

/// Tampons "GARDER" / "SUPPRIMER" qui apparaissent pendant le swipe.
struct StampOverlay: View {
    let dragX: CGFloat
    let threshold: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            HStack {
                stamp("GARDER", color: .green, angle: -14)
                    .opacity(Double(max(0, dragX) / threshold))
                Spacer()
                stamp("SUPPRIMER", color: .red, angle: 14)
                    .opacity(Double(max(0, -dragX) / threshold))
            }
            .padding(24)
            Color.clear
        }
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.system(size: 30, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4))
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Vue principale

struct ContentView: View {
    @StateObject private var store = PhotoSwipeStore()
    @State private var offset: CGSize = .zero
    @State private var isAnimatingOut = false
    @State private var showTrash = false
    @State private var zone = 0 // -1 corbeille, 0 neutre, 1 garder (pour l'haptique)

    private let threshold: CGFloat = 110

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.05, green: 0.05, blue: 0.09), Color(red: 0.11, green: 0.07, blue: 0.16)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            switch store.authorization {
            case .notDetermined:
                permissionView
            case .denied, .restricted:
                deniedView
            default:
                mainView
            }
        }
        .preferredColorScheme(.dark)
        .task {
            if store.isAuthorized && !store.hasLoaded { store.load() }
        }
        .sheet(isPresented: $showTrash) {
            TrashView(store: store)
        }
        .sensoryFeedback(.selection, trigger: zone)
    }

    // MARK: Écran principal

    private var mainView: some View {
        VStack(spacing: 20) {
            header

            ZStack {
                if store.current == nil && store.hasLoaded {
                    finishedView
                } else {
                    ForEach(Array(store.upcoming.enumerated().reversed()), id: \.element.localIdentifier) { i, asset in
                        let isTop = i == 0
                        PhotoCard(asset: asset)
                            .overlay { if isTop { StampOverlay(dragX: offset.width, threshold: threshold) } }
                            .scaleEffect(isTop ? 1 : 1 - CGFloat(i) * 0.05)
                            .offset(y: isTop ? 0 : CGFloat(i) * 16)
                            .offset(isTop ? offset : .zero)
                            .rotationEffect(.degrees(isTop ? Double(offset.width / 18) : 0), anchor: .bottom)
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: store.index)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
            .gesture(dragGesture)

            controls
        }
        .padding(.bottom, 12)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Swipe Photos")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                Text("\(store.remaining) photo\(store.remaining > 1 ? "s" : "") à trier")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showTrash = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: store.trash.isEmpty ? "trash" : "trash.fill")
                    Text("\(store.trash.count)")
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(store.trash.isEmpty ? Color.white.opacity(0.1) : Color.red.opacity(0.85), in: Capsule())
                .foregroundStyle(.white)
                .animation(.snappy, value: store.trash.count)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    private var controls: some View {
        HStack(spacing: 28) {
            roundButton(icon: "xmark", color: .red, size: 68) { swipe(.trash) }
                .disabled(store.current == nil)
            roundButton(icon: "arrow.uturn.backward", color: .yellow, size: 52) { undo() }
                .disabled(!store.canUndo)
                .opacity(store.canUndo ? 1 : 0.35)
            roundButton(icon: "heart.fill", color: .green, size: 68) { swipe(.keep) }
                .disabled(store.current == nil)
        }
    }

    private func roundButton(icon: String, color: Color, size: CGFloat, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)
            Text("Tout est trié !")
                .font(.title.bold())
            if !store.trash.isEmpty {
                Button("Vider la corbeille (\(store.trash.count))") { showTrash = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
            }
            Button("Recommencer depuis le début") { store.resetProgress() }
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Swipe

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isAnimatingOut, store.current != nil else { return }
                offset = value.translation
                let newZone = value.translation.width > threshold ? 1 : (value.translation.width < -threshold ? -1 : 0)
                if newZone != zone { zone = newZone }
            }
            .onEnded { value in
                guard !isAnimatingOut, store.current != nil else { return }
                let projected = value.predictedEndTranslation.width
                if value.translation.width > threshold || projected > 500 {
                    swipe(.keep)
                } else if value.translation.width < -threshold || projected < -500 {
                    swipe(.trash)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { offset = .zero }
                }
                zone = 0
            }
    }

    private func swipe(_ decision: SwipeDecision) {
        guard store.current != nil, !isAnimatingOut else { return }
        isAnimatingOut = true
        let x: CGFloat = decision == .keep ? 650 : -650
        withAnimation(.easeIn(duration: 0.22)) {
            offset = CGSize(width: x, height: offset.height + 60)
        } completion: {
            store.decide(decision)
            offset = .zero
            isAnimatingOut = false
        }
    }

    private func undo() {
        guard let last = store.history.last, !isAnimatingOut else { return }
        store.undo()
        // La carte revient du côté où elle est partie
        offset = CGSize(width: last.decision == .keep ? 650 : -650, height: 60)
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { offset = .zero }
        }
    }

    // MARK: Permissions

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 72))
                .foregroundStyle(.linearGradient(colors: [.pink, .purple], startPoint: .top, endPoint: .bottom))
            Text("Trie ta galerie en swipant")
                .font(.title2.bold())
            Text("Droite pour garder, gauche pour jeter.\nRien n'est supprimé sans ta confirmation.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button {
                Task { await store.requestAccess() }
            } label: {
                Text("Autoriser l'accès aux photos")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.linearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 56)).foregroundStyle(.secondary)
            Text("Accès aux photos refusé").font(.title2.bold())
            Text("Autorise l'accès complet dans Réglages pour pouvoir trier ta galerie.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Ouvrir les Réglages") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

// MARK: - Corbeille

struct TrashView: View {
    @ObservedObject var store: PhotoSwipeStore
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var deletedCount: Int?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        NavigationStack {
            Group {
                if store.trash.isEmpty {
                    ContentUnavailableView(
                        deletedCount.map { "\($0) photo\($0 > 1 ? "s" : "") supprimée\($0 > 1 ? "s" : "") ✨" } ?? "Corbeille vide",
                        systemImage: "trash",
                        description: Text("Swipe à gauche pour ajouter des photos ici.")
                    )
                } else {
                    ScrollView {
                        Text("Touche une photo pour la récupérer.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 8)
                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(store.trash, id: \.localIdentifier) { asset in
                                Button {
                                    withAnimation(.snappy) { store.restore(asset) }
                                } label: {
                                    Thumbnail(asset: asset)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .padding(.bottom, 100)
                    }
                }
            }
            .navigationTitle("Corbeille")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.trash.isEmpty {
                    Button {
                        isDeleting = true
                        Task {
                            let n = await store.emptyTrash()
                            if n > 0 { deletedCount = n }
                            isDeleting = false
                        }
                    } label: {
                        HStack {
                            if isDeleting { ProgressView().tint(.white) }
                            Text("Tout supprimer (\(store.trash.count))")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .foregroundStyle(.white)
                    }
                    .disabled(isDeleting)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

struct Thumbnail: View {
    let asset: PHAsset
    @StateObject private var loader = AssetImageLoader()

    var body: some View {
        Color(white: 0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let img = loader.image {
                    Image(uiImage: img).resizable().scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white, .black.opacity(0.5))
                    .padding(6)
            }
            .onAppear { loader.load(asset, targetSize: CGSize(width: 300, height: 300)) }
            .onDisappear { loader.cancel() }
    }
}

#Preview {
    ContentView()
}
