//
//  SourcePickerView.swift
//  Choix de ce qu'on trie : toute la galerie, un ou plusieurs albums, ou un mois.
//

import SwiftUI
import Combine
import Photos
import UIKit

struct SourcePickerView: View {
    @ObservedObject var store: SwipeStore
    @Environment(\.dismiss) private var dismiss

    private enum Tab: Hashable { case albums, months }

    @State private var tab: Tab = .albums
    @State private var albums: [AlbumInfo] = []
    @State private var months: [MonthInfo] = []
    @State private var isLoading = true
    @State private var selectedAlbumIDs: Set<String> = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        store.select(source: .recent)
                        dismiss()
                    } label: {
                        row(icon: "clock.fill",
                            title: tr("Toute la galerie", "Whole library"),
                            detail: tr("Les plus récentes d'abord", "Newest first"),
                            selected: store.source == .recent)
                    }
                }

                Section {
                    Picker("", selection: $tab) {
                        Text(tr("Albums", "Albums")).tag(Tab.albums)
                        Text(tr("Par mois", "By month")).tag(Tab.months)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                } else if tab == .albums {
                    albumSections
                } else {
                    monthSection
                }
            }
            .navigationTitle(tr("Que veux-tu trier ?", "What to sort?"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(tr("Fermer", "Close")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if tab == .albums && !selectedAlbumIDs.isEmpty {
                    Button {
                        applyAlbumSelection()
                    } label: {
                        Text(selectedAlbumIDs.count == 1
                             ? tr("Trier cet album", "Sort this album")
                             : tr("Trier ces \(selectedAlbumIDs.count) albums", "Sort these \(selectedAlbumIDs.count) albums"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(.linearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
                                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .task { await loadLists() }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Sections

    @ViewBuilder
    private var albumSections: some View {
        let smart = albums.filter(\.isSmart)
        let user = albums.filter { !$0.isSmart }

        if !user.isEmpty {
            Section(tr("Mes albums", "My albums")) {
                ForEach(user) { album in albumRow(album) }
            }
        }
        if !smart.isEmpty {
            Section(tr("Albums automatiques", "Smart albums")) {
                ForEach(smart) { album in albumRow(album) }
            }
        }
        if albums.isEmpty {
            Section {
                Text(tr("Aucun album trouvé.", "No albums found."))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monthSection: some View {
        Section(tr("Par mois", "By month")) {
            ForEach(months) { month in
                Button {
                    store.select(source: .month(month.key))
                    dismiss()
                } label: {
                    row(icon: "calendar",
                        title: month.key.title,
                        detail: "\(month.count)",
                        selected: store.source == .month(month.key))
                }
            }
        }
    }

    private func albumRow(_ album: AlbumInfo) -> some View {
        let isSelected = selectedAlbumIDs.contains(album.id)
        return Button {
            if isSelected {
                selectedAlbumIDs.remove(album.id)
            } else {
                selectedAlbumIDs.insert(album.id)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.pink : Color.secondary)
                Text(album.title)
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(album.count)")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
    }

    private func row(icon: String, title: String, detail: String, selected: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.pink)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.pink)
            }
        }
    }

    // MARK: Actions

    private func applyAlbumSelection() {
        let chosen = albums.filter { selectedAlbumIDs.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let title = chosen.count == 1
            ? chosen[0].title
            : tr("\(chosen.count) albums", "\(chosen.count) albums")
        store.select(source: .albums(ids: chosen.map(\.id), title: title))
        dismiss()
    }

    private func loadLists() async {
        if case .albums(let ids, _) = store.source {
            selectedAlbumIDs = Set(ids)
        }
        if case .month = store.source {
            tab = .months
        }
        let filter = store.filter
        let lists = await Task.detached(priority: .userInitiated) {
            (LibraryService.fetchAlbums(), LibraryService.fetchMonths(filter: filter))
        }.value
        albums = lists.0
        months = lists.1
        isLoading = false
    }
}
