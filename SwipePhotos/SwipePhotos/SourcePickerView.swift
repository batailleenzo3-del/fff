//
//  SourcePickerView.swift
//  Choix de ce qu'on trie : toute la galerie, un ou plusieurs albums, ou un mois.
//

import SwiftUI
import Combine
import Photos

struct SourcePickerView: View {
    @Environment(\.appTheme) private var theme
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
                        row(icon: "photo.on.rectangle",
                            title: loc("whole_library"),
                            detail: "",
                            selected: store.source == .recent)
                    }
                }

                Section {
                    Picker("", selection: $tab) {
                        Text(loc("albums")).tag(Tab.albums)
                        Text(loc("by_month")).tag(Tab.months)
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
            .navigationTitle(loc("what_to_sort"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("close")) { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if tab == .albums && !selectedAlbumIDs.isEmpty {
                    Button {
                        applyAlbumSelection()
                    } label: {
                        Text(selectedAlbumIDs.count == 1
                             ? loc("sort_this_album")
                             : loc("sort_these_albums", selectedAlbumIDs.count))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(theme.gradient,
                                        in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }
            }
            .task { await loadLists() }
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var albumSections: some View {
        let smart = albums.filter(\.isSmart)
        let user = albums.filter { !$0.isSmart }

        if !user.isEmpty {
            Section(loc("my_albums")) {
                ForEach(user) { album in albumRow(album) }
            }
        }
        if !smart.isEmpty {
            Section(loc("smart_albums")) {
                ForEach(smart) { album in albumRow(album) }
            }
        }
        if albums.isEmpty {
            Section {
                Text(loc("no_albums"))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var monthSection: some View {
        Section(loc("by_month")) {
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
                    .foregroundStyle(isSelected ? theme.primary : Color.secondary)
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
                .foregroundStyle(theme.primary)
                .frame(width: 24)
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            Text(detail)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            if selected {
                Image(systemName: "checkmark")
                    .foregroundStyle(theme.primary)
            }
        }
    }

    // MARK: Actions

    private func applyAlbumSelection() {
        let chosen = albums.filter { selectedAlbumIDs.contains($0.id) }
        guard !chosen.isEmpty else { return }
        let title = chosen.count == 1 ? chosen[0].title : loc("n_albums", chosen.count)
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
