//
//  DuplicatesView.swift
//  Onglet « Doublons » : photos similaires regroupées, on garde la meilleure.
//

import SwiftUI
import Combine
import Photos

struct DuplicatesView: View {
    @ObservedObject var store: SwipeStore
    @Binding var showTrash: Bool

    /// Pour chaque groupe : les photos que l'utilisateur veut jeter (sinon : toutes sauf la meilleure).
    @State private var selections: [String: Set<String>] = [:]

    var body: some View {
        Group {
            if let progress = store.similarProgress {
                scanningView(progress)
            } else if let groups = store.similarGroups {
                if groups.isEmpty {
                    emptyView
                } else {
                    groupList(groups)
                }
            } else {
                Color.clear
            }
        }
        .frame(maxHeight: .infinity)
        .task { store.scanSimilar() }
    }

    // MARK: États

    private func scanningView(_ progress: Double) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 44))
                .foregroundStyle(LinearGradient.brand)
                .frame(width: 100, height: 100)
                .glassBackground(in: Circle())
            Text(loc("dup_scanning", Int(progress * 100)))
                .font(.headline)
            ProgressView(value: progress)
                .tint(.pink)
                .frame(maxWidth: 260)
            Text(loc("dup_scanning_hint"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(loc("dup_none_title"))
                .font(.title2.bold())
            Text(loc("dup_none_text"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(loc("dup_rescan")) { store.scanSimilar(force: true) }
                .buttonStyle(.bordered)
        }
        .padding(28)
    }

    private func groupList(_ groups: [SimilarGroup]) -> some View {
        ScrollView {
            VStack(spacing: 14) {
                VStack(spacing: 10) {
                    Text(loc("dup_summary", groups.count, totalSelected(groups)))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    HStack(spacing: 10) {
                        Button {
                            for group in groups {
                                store.resolveGroup(group, trashIDs: selection(for: group))
                            }
                            selections.removeAll()
                        } label: {
                            Label(loc("dup_trash_all", totalSelected(groups)), systemImage: "trash.fill")
                                .font(.subheadline.weight(.semibold))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.red, in: Capsule())
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                        .disabled(totalSelected(groups) == 0)

                        Button {
                            store.scanSimilar(force: true)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.subheadline.weight(.semibold))
                                .frame(width: 40, height: 40)
                                .glassBackground(in: Circle(), interactive: true)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(loc("dup_rescan"))
                    }
                }
                .padding(.top, 4)

                ForEach(groups) { group in
                    groupCard(group)
                }

                if !store.trash.isEmpty {
                    Button(loc("dup_open_trash", store.trash.count)) { showTrash = true }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
    }

    // MARK: Un groupe

    private func groupCard(_ group: SimilarGroup) -> some View {
        let toTrash = selection(for: group)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(loc("dup_group_title", group.assets.count))
                    .font(.headline)
                Spacer()
                if let date = group.assets.first?.creationDate {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(group.assets, id: \.localIdentifier) { asset in
                        let id = asset.localIdentifier
                        let marked = toTrash.contains(id)
                        Button {
                            toggle(id, in: group)
                        } label: {
                            AssetThumbnail(asset: asset)
                                .frame(width: 112, height: 112)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay {
                                    if marked {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Color.black.opacity(0.45))
                                        Image(systemName: "trash.circle.fill")
                                            .font(.system(size: 30))
                                            .foregroundStyle(.white, .red)
                                    }
                                }
                                .overlay(alignment: .bottomLeading) {
                                    if id == group.bestID && !marked {
                                        Label(loc("dup_best"), systemImage: "star.fill")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.green, in: Capsule())
                                            .padding(6)
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .strokeBorder(marked ? Color.red : Color.green.opacity(0.8), lineWidth: 2)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(marked ? loc("dup_marked") : loc("dup_kept"))
                    }
                }
            }

            HStack {
                Button(loc("dup_keep_all")) {
                    selections[group.id] = nil
                    store.dismissGroup(group)
                }
                .font(.subheadline)
                Spacer()
                Button {
                    store.resolveGroup(group, trashIDs: toTrash)
                    selections[group.id] = nil
                } label: {
                    Text(loc("dup_trash_n", toTrash.count))
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(toTrash.isEmpty ? Color.gray : Color.red, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(toTrash.isEmpty)
            }
        }
        .padding(16)
        .glassBackground(in: RoundedRectangle(cornerRadius: 26, style: .continuous))
    }

    // MARK: Sélection

    private func selection(for group: SimilarGroup) -> Set<String> {
        if let custom = selections[group.id] { return custom }
        return Set(group.assets.map(\.localIdentifier)).subtracting([group.bestID])
    }

    private func toggle(_ id: String, in group: SimilarGroup) {
        var current = selection(for: group)
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        selections[group.id] = current
    }

    private func totalSelected(_ groups: [SimilarGroup]) -> Int {
        groups.reduce(0) { $0 + selection(for: $1).count }
    }
}
