//
//  MediaViews.swift
//  Affichage des photos et vidéos : grande carte, miniatures, lecteur vidéo.
//

import SwiftUI
import Combine
import Photos
import AVFoundation
import AVFAudio
import UIKit

// MARK: - Chargement d'image

@MainActor
final class AssetImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var requestID: PHImageRequestID?

    func load(_ asset: PHAsset, targetSize: CGSize) {
        guard requestID == nil else { return }
        requestID = Self.request(asset, targetSize: targetSize) { [weak self] image in
            guard let image else { return }
            Task { @MainActor [weak self] in
                self?.image = image
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
        completion: @escaping @Sendable (UIImage?) -> Void
    ) -> PHImageRequestID {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true // photos stockées sur iCloud
        return PHImageManager.default().requestImage(
            for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options
        ) { image, _ in
            completion(image)
        }
    }
}

// MARK: - Chargement vidéo

nonisolated struct PlayerItemBox: @unchecked Sendable {
    let item: AVPlayerItem?
}

@MainActor
final class VideoLoader: ObservableObject {
    @Published var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var requestID: PHImageRequestID?

    func load(_ asset: PHAsset, muted: Bool) {
        guard player == nil, requestID == nil else { return }
        requestID = Self.request(asset) { [weak self] box in
            Task { @MainActor [weak self] in
                guard let self, let item = box.item, self.requestID != nil else { return }
                let queuePlayer = AVQueuePlayer()
                queuePlayer.isMuted = muted
                self.looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
                self.player = queuePlayer
                queuePlayer.play()
            }
        }
    }

    func setMuted(_ muted: Bool) {
        player?.isMuted = muted
        if !muted {
            // Permet d'entendre le son même si l'iPhone est en mode silencieux
            try? AVAudioSession.sharedInstance().setCategory(.playback)
        }
    }

    func stop() {
        if let requestID { PHImageManager.default().cancelImageRequest(requestID) }
        requestID = nil
        player?.pause()
        looper = nil
        player = nil
    }

    nonisolated private static func request(
        _ asset: PHAsset,
        completion: @escaping @Sendable (PlayerItemBox) -> Void
    ) -> PHImageRequestID {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .automatic
        return PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
            completion(PlayerItemBox(item: item))
        }
    }
}

/// Affiche un AVPlayer (sans boutons de contrôle).
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ view: PlayerUIView, context: Context) {
        if view.playerLayer.player !== player {
            view.playerLayer.player = player
        }
    }
}

final class PlayerUIView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

// MARK: - Grande carte

struct MediaCard: View {
    let asset: PHAsset
    let isTop: Bool

    @StateObject private var imageLoader = AssetImageLoader()
    @StateObject private var videoLoader = VideoLoader()
    @AppStorage("swipe.videoMuted") private var muted = true
    @State private var sizeText: String?
    @Environment(\.displayScale) private var scale

    private var isVideo: Bool { asset.mediaType == .video }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(white: 0.1)

                if let image = imageLoader.image {
                    // Fond flou + média entier par-dessus
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 30)
                        .opacity(0.6)
                        .clipped()
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width, height: geo.size.height)
                } else {
                    ProgressView().tint(.white)
                }

                if isTop, isVideo, let player = videoLoader.player {
                    PlayerLayerView(player: player)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    infoBar
                }
            }
            .onAppear {
                imageLoader.load(asset, targetSize: CGSize(width: geo.size.width * scale,
                                                           height: geo.size.height * scale))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, y: 10)
        .task(id: isTop) {
            guard isTop else {
                videoLoader.stop()
                return
            }
            if sizeText == nil {
                sizeText = L10n.bytes(LibraryService.fileSize(of: asset))
            }
            if isVideo {
                videoLoader.load(asset, muted: muted)
            }
        }
        .onChange(of: muted) { _, newValue in
            videoLoader.setMuted(newValue)
        }
        .onDisappear {
            videoLoader.stop()
            imageLoader.cancel()
        }
    }

    private var infoBar: some View {
        HStack(spacing: 10) {
            if let date = asset.creationDate {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote.weight(.semibold))
            }
            Spacer()
            if let sizeText {
                Text(sizeText)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15), in: Capsule())
            }
            if isVideo {
                Label(L10n.duration(asset.duration), systemImage: "play.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.15), in: Capsule())
                if isTop {
                    Button {
                        muted.toggle()
                    } label: {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.15), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(muted ? tr("Activer le son", "Unmute") : tr("Couper le son", "Mute"))
                }
            }
            if asset.isFavorite {
                Image(systemName: "heart.fill").foregroundStyle(.pink)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        )
    }
}

// MARK: - Tampons GARDER / SUPPRIMER

struct StampOverlay: View {
    let dragX: CGFloat
    let threshold: CGFloat

    var body: some View {
        VStack {
            HStack {
                stamp(tr("GARDER", "KEEP"), color: .green, angle: -14)
                    .opacity(Double(max(0, dragX) / threshold))
                Spacer()
                stamp(tr("SUPPRIMER", "DELETE"), color: .red, angle: 14)
                    .opacity(Double(max(0, -dragX) / threshold))
            }
            .padding(24)
            Spacer()
        }
        .allowsHitTesting(false)
    }

    private func stamp(_ text: String, color: Color, angle: Double) -> some View {
        Text(text)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(color, lineWidth: 4))
            .background(.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
            .rotationEffect(.degrees(angle))
    }
}

// MARK: - Miniature (corbeille)

struct Thumbnail: View {
    let asset: PHAsset
    @StateObject private var loader = AssetImageLoader()

    var body: some View {
        Color(white: 0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = loader.image {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            }
            .clipped()
            .overlay(alignment: .topLeading) {
                if asset.mediaType == .video {
                    Label(L10n.duration(asset.duration), systemImage: "play.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(5)
                        .background(.black.opacity(0.45), in: Capsule())
                        .padding(5)
                }
            }
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
