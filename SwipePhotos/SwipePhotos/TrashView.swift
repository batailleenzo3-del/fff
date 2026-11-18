//
//  TrashView.swift
//  La corbeille : on récupère ce qu'on veut, puis on supprime tout d'un coup.
//

import SwiftUI
import Combine
import Photos
import UIKit

struct TrashView: View {
    @ObservedObject var store: SwipeStore
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleting = false
    @State private var lastResult: (count: Int, bytes: Int64)?

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 4)]

    var body: some View {
        NavigationStack {
            Group {
                if store.trash.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 4) {
                            Text(tr("\(store.trash.count) éléments · \(L10n.bytes(store.trashBytes)) à libérer",
                                    "\(store.trash.count) items · \(L10n.bytes(store.trashBytes)) to free"))
                                .font(.headline)
                            Text(tr("Touche une photo pour la récupérer.", "Tap a photo to keep it."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
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
                        .padding(.bottom, 110)
                    }
                }
            }
            .navigationTitle(tr("Corbeille", "Trash"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(tr("OK", "Done")) { dismiss() }
                }
                if !store.trash.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(tr("Tout garder", "Keep all")) {
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
        }
        .preferredColorScheme(.dark)
    }

    private var deleteButton: some View {
        Button {
            isDeleting = true
            Task {
                if let result = await store.emptyTrash() {
                    lastResult = result
                }
                isDeleting = false
            }
        } label: {
            HStack(spacing: 8) {
                if isDeleting { ProgressView().tint(.white) }
                Text(tr("Supprimer \(store.trash.count) éléments · \(L10n.bytes(store.trashBytes))",
                        "Delete \(store.trash.count) items · \(L10n.bytes(store.trashBytes))"))
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

    private var emptyState: some View {
        VStack(spacing: 16) {
            if let result = lastResult {
                Image(systemName: "sparkles")
                    .font(.system(size: 56))
                    .foregroundStyle(.linearGradient(colors: [.pink, .purple], startPoint: .top, endPoint: .bottom))
                Text(tr("\(result.count) éléments supprimés", "\(result.count) items deleted"))
                    .font(.title2.bold())
                Text(tr("\(L10n.bytes(result.bytes)) libérés", "\(L10n.bytes(result.bytes)) freed"))
                    .font(.title3)
                    .foregroundStyle(.green)
                Text(tr("Ils sont dans « Supprimés récemment » de l'app Photos pendant 30 jours. Vide cet album pour récupérer l'espace tout de suite.",
                        "They stay in “Recently Deleted” in the Photos app for 30 days. Empty that album to free the space right away."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Image(systemName: "trash")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text(tr("Corbeille vide", "Trash is empty"))
                    .font(.title2.bold())
                Text(tr("Swipe à gauche pour ajouter des photos ici.", "Swipe left to add photos here."))
                    .foregroundStyle(.secondary)
            }
            if store.totalFreedBytes > 0 {
                Text(tr("Total depuis le début : \(store.totalDeletedCount) éléments · \(L10n.bytes(store.totalFreedBytes))",
                        "All-time total: \(store.totalDeletedCount) items · \(L10n.bytes(store.totalFreedBytes))"))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(32)
    }
}
