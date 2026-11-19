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
    @Published var failed = false
    private var requestID: PHImageRequestID?

    func load(_ asset: PHAsset, targetSize: CGSize) {
        guard requestID == nil else { return }
        failed = false
        requestID = Self.request(asset, targetSize: targetSize) { [weak self] image in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let image {
                    self.image = image
                } else if self.image == nil {
                    self.failed = true
                }
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
    @Published var failed = false
    private var looper: AVPlayerLooper?
    private var requestID: PHImageRequestID?

    func load(_ asset: PHAsset, muted: Bool) {
        guard player == nil, requestID == nil else { return }
        failed = false
        requestID = Self.request(asset) { [weak self] box in
            Task { @MainActor [weak self] in
                guard let self, self.requestID != nil else { return }
                guard let item = box.item else {
                    self.failed = true
                    return
                }
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
    @AppStorage(SettingsKey.videoMuted) private var muted = true
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
                } else if imageLoader.failed {
                    unavailable(icon: "icloud.slash", text: loc("media_unavailable"))
                } else {
                    ProgressView().tint(.white)
                }

                if isTop, isVideo, let player = videoLoader.player {
                    PlayerLayerView(player: player)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .allowsHitTesting(false)
                }

                if isTop, isVideo, videoLoader.failed {
                    VStack {
                        Label(loc("video_unavailable"), systemImage: "exclamationmark.icloud")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(.top, 16)
                        Spacer()
                    }
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
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
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

    private func unavailable(icon: String, text: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: icon).font(.system(size: 40))
            Text(text).font(.footnote).multilineTextAlignment(.center)
        }
        .foregroundStyle(.white.opacity(0.7))
        .padding(32)
    }

    private var infoBar: some View {
        HStack(spacing: 8) {
            if let date = asset.creationDate {
                Text(date.formatted(date: .abbreviated, time: .shortened))
                    .font(.footnote.weight(.semibold))
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            if let sizeText {
                chip(sizeText)
            }
            if isVideo {
                chip(L10n.duration(asset.duration), icon: "play.fill")
                if isTop {
                    Button {
                        muted.toggle()
                    } label: {
                        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                            .font(.footnote.weight(.semibold))
                            .frame(width: 34, height: 34)
                            .glassBackground(in: Circle(), interactive: true)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(muted ? loc("unmute") : loc("mute"))
                }
            }
            if asset.isFavorite {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        )
        .environment(\.colorScheme, .dark)
    }

    private func chip(_ text: String, icon: String? = nil) -> some View {
        HStack(spacing: 4) {
            if let icon { Image(systemName: icon) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .glassBackground(in: Capsule())
    }
}

// MARK: - Tampons GARDER / SUPPRIMER / FAVORI

struct StampOverlay: View {
    let offset: CGSize
    let threshold: CGFloat

    var body: some View {
        let horizontal = abs(offset.width) >= abs(offset.height)
        VStack {
            HStack {
                stamp(loc("stamp_keep"), color: .green, angle: -14)
                    .opacity(horizontal ? Double(max(0, offset.width) / threshold) : 0)
                Spacer()
                stamp(loc("stamp_delete"), color: .red, angle: 14)
                    .opacity(horizontal ? Double(max(0, -offset.width) / threshold) : 0)
            }
            .padding(24)
            Spacer()
            stamp(loc("stamp_favorite"), color: .yellow, angle: 0)
                .opacity(horizontal ? 0 : Double(max(0, -offset.height) / threshold))
                .padding(.bottom, 90)
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

// MARK: - Miniature

struct AssetThumbnail: View {
    let asset: PHAsset
    var showsRestoreIcon = false

    @StateObject private var loader = AssetImageLoader()

    var body: some View {
        Color(white: 0.15)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image = loader.image {
                    Image(uiImage: image).resizable().scaledToFill()
                } else if loader.failed {
                    Image(systemName: "icloud.slash").foregroundStyle(.white.opacity(0.6))
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
                if showsRestoreIcon {
                    Image(systemName: "arrow.uturn.backward.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.white, .black.opacity(0.5))
                        .padding(6)
                }
            }
            .onAppear { loader.load(asset, targetSize: CGSize(width: 300, height: 300)) }
            .onDisappear { loader.cancel() }
    }
}
