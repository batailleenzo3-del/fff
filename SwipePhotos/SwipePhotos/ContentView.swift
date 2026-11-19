//
//  ContentView.swift
//  Écran principal : la pile de cartes à swiper.
//
//  ➜ Droite : garder        ➜ Gauche : corbeille (rien n'est supprimé tout de suite)
//  ➜ Bouton corbeille en haut : tout supprimer en UNE seule confirmation iOS
//

import SwiftUI
import Combine
import Photos
import UIKit

struct ContentView: View {
    @StateObject private var store = SwipeStore()
    @Environment(\.scenePhase) private var scenePhase

    @State private var offset: CGSize = .zero
    @State private var isAnimatingOut = false
    @State private var showTrash = false
    @State private var showSourcePicker = false
    @State private var zone = 0 // -1 corbeille, 0 neutre, 1 garder (vibration)

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
            if store.isAuthorized && !store.hasLoaded { store.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                store.persistNow() // on garde la position exacte
            case .active:
                // Pas de rechargement : on reste sur la même photo.
                // Seule exception : plus de 24 h depuis le dernier retour au début.
                store.becameActive()
            default:
                break
            }
        }
        .sheet(isPresented: $showTrash) {
            TrashView(store: store)
        }
        .sheet(isPresented: $showSourcePicker) {
            SourcePickerView(store: store)
        }
        .sensoryFeedback(.selection, trigger: zone)
    }

    // MARK: Écran principal

    private var mainView: some View {
        VStack(spacing: 14) {
            header

            Picker(tr("Type de média", "Media type"), selection: Binding(
                get: { store.filter },
                set: { store.select(filter: $0) }
            )) {
                ForEach(MediaFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            if store.newItemsCount > 0 && !store.isLoading {
                Button {
                    store.showNewItems()
                } label: {
                    Label(store.newItemsCount > 1
                          ? tr("\(store.newItemsCount) nouvelles photos · Afficher", "\(store.newItemsCount) new photos · Show")
                          : tr("1 nouvelle photo · Afficher", "1 new photo · Show"),
                          systemImage: "sparkles")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(.linearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
                                    in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            ZStack {
                if !store.hasLoaded || store.isLoading {
                    VStack(spacing: 14) {
                        ProgressView().controlSize(.large).tint(.white)
                        Text(tr("Chargement…", "Loading…")).foregroundStyle(.secondary)
                    }
                } else if store.current == nil {
                    finishedView
                } else {
                    ForEach(Array(store.upcoming.enumerated().reversed()), id: \.element.localIdentifier) { i, asset in
                        let isTop = i == 0
                        MediaCard(asset: asset, isTop: isTop)
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
        .animation(.snappy, value: store.newItemsCount)
    }

    private var header: some View {
        HStack(alignment: .center) {
            Button {
                showSourcePicker = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.sourceTitle)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .lineLimit(1)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityHint(tr("Choisir l'album ou le mois à trier", "Choose the album or month to sort"))

            Spacer(minLength: 12)

            refreshMenu

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
            .accessibilityLabel(tr("Corbeille, \(store.trash.count) éléments", "Trash, \(store.trash.count) items"))
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    /// Bouton ↻ : nouvelles photos ou retour au début.
    private var refreshMenu: some View {
        Menu {
            Button {
                store.showNewItems()
            } label: {
                Label(store.newItemsCount > 0
                      ? tr("Afficher les nouvelles photos (\(store.newItemsCount))", "Show new photos (\(store.newItemsCount))")
                      : tr("Chercher de nouvelles photos", "Check for new photos"),
                      systemImage: "sparkles")
            }
            Button {
                store.restartFromNewest()
            } label: {
                Label(tr("Repartir des plus récentes", "Start over from newest"), systemImage: "arrow.counterclockwise")
            }
            Text(tr("Tu reprends toujours là où tu t'es arrêté. Retour automatique aux plus récentes toutes les 24 h.",
                    "You always resume where you left off. Automatic return to newest every 24 h."))
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 42, height: 42)
                .background(Color.white.opacity(0.1), in: Circle())
                .overlay(alignment: .topTrailing) {
                    if store.newItemsCount > 0 {
                        Circle()
                            .fill(Color.pink)
                            .frame(width: 11, height: 11)
                            .offset(x: 1, y: -1)
                    }
                }
        }
        .accessibilityLabel(tr("Actualiser", "Refresh"))
    }

    private var subtitle: String {
        var text = tr("\(store.remaining) à trier", "\(store.remaining) to sort")
        if store.totalFreedBytes > 0 {
            text += " · " + tr("\(L10n.bytes(store.totalFreedBytes)) libérés", "\(L10n.bytes(store.totalFreedBytes)) freed")
        }
        return text
    }

    private var controls: some View {
        HStack(spacing: 28) {
            roundButton(icon: "xmark", color: .red, size: 68, label: tr("Corbeille", "Trash")) { swipe(.trash) }
                .disabled(store.current == nil)
            roundButton(icon: "arrow.uturn.backward", color: .yellow, size: 52, label: tr("Annuler", "Undo")) { undo() }
                .disabled(!store.canUndo)
                .opacity(store.canUndo ? 1 : 0.35)
            roundButton(icon: "heart.fill", color: .green, size: 68, label: tr("Garder", "Keep")) { swipe(.keep) }
                .disabled(store.current == nil)
        }
    }

    private func roundButton(icon: String, color: Color, size: CGFloat, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay(Circle().stroke(color.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            if store.deck.isEmpty {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text(tr("Rien à trier ici", "Nothing to sort here"))
                    .font(.title2.bold())
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text(tr("Tout est trié !", "All sorted!"))
                    .font(.title.bold())
                Text(tr("\(store.keptCount) gardées · \(store.trash.count) dans la corbeille",
                        "\(store.keptCount) kept · \(store.trash.count) in trash"))
                    .foregroundStyle(.secondary)
            }
            if !store.trash.isEmpty {
                Button(tr("Vider la corbeille (\(L10n.bytes(store.trashBytes)))",
                          "Empty trash (\(L10n.bytes(store.trashBytes)))")) {
                    showTrash = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            Button(tr("Choisir un album ou un mois", "Choose an album or month")) {
                showSourcePicker = true
            }
            .buttonStyle(.bordered)
            Button(tr("Revoir depuis les plus récentes", "Review again from newest")) { store.restartFromNewest() }
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
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
            Text(tr("Trie ta galerie en swipant", "Sort your gallery by swiping"))
                .font(.title2.bold())
            VStack(alignment: .leading, spacing: 12) {
                featureRow("hand.draw.fill", tr("Droite pour garder, gauche pour jeter", "Right to keep, left to delete"))
                featureRow("film.fill", tr("Photos et vidéos, par album ou par mois", "Photos and videos, by album or month"))
                featureRow("trash.fill", tr("Une seule confirmation pour tout supprimer", "One confirmation to delete everything"))
                featureRow("lock.fill", tr("Rien ne quitte ton iPhone", "Nothing leaves your iPhone"))
            }
            .padding(.vertical, 8)
            Button {
                Task { await store.requestAccess() }
            } label: {
                Text(tr("Autoriser l'accès aux photos", "Allow photo access"))
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(.linearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
                                in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .padding(32)
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.pink)
                .frame(width: 26)
            Text(text)
                .foregroundStyle(.secondary)
        }
    }

    private var deniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill").font(.system(size: 56)).foregroundStyle(.secondary)
            Text(tr("Accès aux photos refusé", "Photo access denied")).font(.title2.bold())
            Text(tr("Autorise l'accès complet dans Réglages pour pouvoir trier ta galerie.",
                    "Allow full access in Settings to sort your gallery."))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(tr("Ouvrir les Réglages", "Open Settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

#Preview {
    ContentView()
}
