//
//  TrashView.swift
//  La corbeille : on récupère ce qu'on veut, puis on supprime tout d'un coup.
//

import SwiftUI
import Combine
import Photos
import StoreKit

struct TrashView: View {
    @ObservedObject var store: SwipeStore
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @AppStorage(SettingsKey.reviewRequested) private var reviewRequested = false

    @State private var isDeleting = false
    @State private var lastResult: (count: Int, bytes: Int64)?
    @State private var showPaywall = false
    @State private var confetti = 0

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if store.trash.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            Text(loc("trash_summary", store.trash.count, L10n.bytes(store.trashBytes)))
                                .font(.headline)
                            Text(loc("trash_tap_to_restore"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            if !purchases.isPro {
                                Text(loc("free_deletions_left", store.freeDeletionsLeft))
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.pink)
                            }
                        }
                        .padding(.top, 8)

                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(store.trash, id: \.localIdentifier) { asset in
                                Button {
                                    withAnimation(.snappy) { store.restore(asset) }
                                } label: {
                                    AssetThumbnail(asset: asset, showsRestoreIcon: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .padding(.bottom, 110)
                    }
                }
            }
            .overlay { ConfettiView(trigger: confetti) }
            .navigationTitle(loc("trash_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("done")) { dismiss() }
                }
                if !store.trash.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(loc("keep_all")) {
                            withAnimation(.snappy) { store.restoreAll() }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !store.trash.isEmpty {
                    deleteButton
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView(purchases: purchases)
                    .appAppearance()
            }
        }
    }

    private var deleteButton: some View {
        Button {
            if store.needsPro(isPro: purchases.isPro) {
                showPaywall = true
                return
            }
            isDeleting = true
            Task {
                if let result = await store.emptyTrash() {
                    lastResult = result
                    confetti += 1
                    askForReviewIfNeeded()
                }
                isDeleting = false
            }
        } label: {
            HStack(spacing: 8) {
                if isDeleting { ProgressView().tint(.white) }
                Text(loc("delete_n_items", store.trash.count, L10n.bytes(store.trashBytes)))
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.red, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
        .disabled(isDeleting)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            if let result = lastResult {
                Image(systemName: "sparkles")
                    .font(.system(size: 52))
                    .foregroundStyle(LinearGradient.brand)
                    .frame(width: 110, height: 110)
                    .glassBackground(in: Circle())
                Text(loc("deleted_result", result.count))
                    .font(.title2.bold())
                Text(loc("freed_result", L10n.bytes(result.bytes)))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.green)
                Text(loc("recently_deleted_hint"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "trash")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                    .frame(width: 110, height: 110)
                    .glassBackground(in: Circle())
                Text(loc("trash_empty_title"))
                    .font(.title2.bold())
                Text(loc("trash_empty_text"))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if store.totalFreedBytes > 0 {
                Text(loc("all_time_total", store.totalDeletedCount, L10n.bytes(store.totalFreedBytes)))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(32)
    }

    /// Demande une note sur l'App Store une seule fois, après un vrai succès.
    private func askForReviewIfNeeded() {
        guard !reviewRequested, store.totalDeletedCount >= 20 else { return }
        reviewRequested = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            requestReview()
        }
    }
}
