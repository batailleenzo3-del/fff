//
//  SwipeScreen.swift
//  Écran principal : la pile de cartes à swiper.
//
//  ➜ Droite : garder     ➜ Gauche : corbeille     ➜ Haut : favori
//

import SwiftUI
import Combine
import Photos
import UIKit

/// Onglets sous le titre.
enum MainTab: Hashable {
    case media(MediaFilter)
    case duplicates
}

struct SwipeScreen: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: SwipeStore
    @ObservedObject var purchases: PurchaseManager

    @AppStorage(SettingsKey.haptics) private var hapticsEnabled = true

    @State private var offset: CGSize = .zero
    @State private var isAnimatingOut = false
    @State private var showTrash = false
    @State private var showSourcePicker = false
    @State private var showSettings = false
    @State private var showPaywall = false
    @State private var showFeedback = false
    @State private var showingDuplicates = false
    @State private var zone = 0 // -1 corbeille, 0 neutre, 1 garder, 2 favori
    @State private var refreshSpins = 0
    @Namespace private var tabNamespace
    @AppStorage(SettingsKey.photoBackdrop) private var photoBackdrop = true

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 12) {
            header
            tabs
            if store.authorization == .limited {
                limitedBanner
            }
            if !purchases.isPro && !showingDuplicates && store.freeSwipesLeft <= 20 {
                freeSwipesBanner
            }

            if showingDuplicates {
                DuplicatesView(store: store, showTrash: $showTrash)
                    .frame(maxWidth: 700)
            } else {
                cardStack
                    .frame(maxWidth: 560)
                controls
            }
        }
        .padding(.bottom, 10)
        .background {
            // Fond flou fait à partir de la photo affichée : le verre prend ses couleurs
            if photoBackdrop && !showingDuplicates, let asset = store.current {
                PhotoBackdrop(asset: asset)
                    .id(asset.localIdentifier)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: store.current?.localIdentifier)
        .overlay {
            ConfettiView(trigger: store.celebrateTrigger)
        }
        .sensoryFeedback(.selection, trigger: zone) { _, _ in hapticsEnabled }
        .sensoryFeedback(trigger: store.decisionCount) { _, _ in
            guard hapticsEnabled else { return nil }
            switch store.lastDecision {
            case .trash: return .impact(weight: .medium)
            case .favorite: return .success
            default: return .impact(weight: .light)
            }
        }
        .sensoryFeedback(.success, trigger: store.celebrateTrigger) { _, _ in hapticsEnabled }
        .sheet(isPresented: $showTrash) {
            TrashView(store: store, purchases: purchases)
                .appAppearance()
        }
        .sheet(isPresented: $showSourcePicker) {
            SourcePickerView(store: store)
                .appAppearance()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store, purchases: purchases)
                .appAppearance()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(purchases: purchases)
                .appAppearance()
        }
        .sheet(isPresented: $showFeedback) {
            FeedbackView()
                .appAppearance()
        }
    }

    // MARK: En-tête

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                showSourcePicker = true
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(store.sourceTitle)
                            .font(.system(.title, design: .rounded, weight: .heavy))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Image(systemName: "chevron.down.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            .accessibilityHint(loc("choose_source_hint"))

            Spacer(minLength: 6)

            GlassIconButton(icon: "lightbulb.fill", tint: .yellow, size: 40, accessibility: loc("feedback_title")) {
                showFeedback = true
            }

            GlassIconButton(icon: "gearshape.fill", size: 40, accessibility: loc("settings_title")) {
                showSettings = true
            }

            refreshButton

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
                .foregroundStyle(store.trash.isEmpty ? Color.primary : Color.white)
                .padding(.horizontal, 12)
                .frame(height: 40)
                .glassBackground(in: Capsule(), tint: store.trash.isEmpty ? nil : .red, interactive: true)
                .animation(.snappy, value: store.trash.count)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(loc("trash_accessibility", store.trash.count))
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    private var subtitle: String {
        var text = loc("to_sort", store.remaining)
        if store.totalFreedBytes > 0 {
            text += " · " + loc("freed_short", L10n.bytes(store.totalFreedBytes))
        }
        return text
    }

    /// Bouton ↻ : un seul appui = retour aux photos les plus récentes de la galerie.
    private var refreshButton: some View {
        Button {
            refreshSpins += 1
            showingDuplicates = false
            store.refreshToNewest()
        } label: {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .rotationEffect(.degrees(Double(refreshSpins) * 360))
                .animation(.easeInOut(duration: 0.5), value: refreshSpins)
                .frame(width: 40, height: 40)
                .glassBackground(in: Circle(), interactive: true)
                .overlay(alignment: .topTrailing) {
                    // Point rose = de nouvelles photos sont arrivées
                    if store.newItemsCount > 0 {
                        Circle()
                            .fill(theme.primary)
                            .frame(width: 11, height: 11)
                            .offset(x: 1, y: -1)
                    }
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: refreshSpins) { _, _ in hapticsEnabled }
        .accessibilityLabel(loc("refresh_accessibility"))
    }

    // MARK: Onglets

    /// Barre d'onglets en verre (Tout · Photos · Vidéos · Doublons).
    private var tabs: some View {
        let current: MainTab = showingDuplicates ? .duplicates : .media(store.filter)
        let items: [(tab: MainTab, title: String)] =
            MediaFilter.allCases.map { (tab: MainTab.media($0), title: $0.title) }
            + [(tab: MainTab.duplicates, title: loc("tab_duplicates"))]
        return HStack(spacing: 4) {
            ForEach(items, id: \.tab) { item in
                let selected = item.tab == current
                Button {
                    select(tab: item.tab)
                } label: {
                    Text(item.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .foregroundStyle(selected ? Color.white : Color.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(theme.gradient)
                                    .shadow(color: theme.primary.opacity(0.45), radius: 8, y: 3)
                                    .matchedGeometryEffect(id: "selectedTab", in: tabNamespace)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(4)
        .glassBackground(in: Capsule())
        .padding(.horizontal, 20)
        .frame(maxWidth: 700)
        .animation(.snappy(duration: 0.3), value: current)
    }

    private func select(tab: MainTab) {
        switch tab {
        case .media(let filter):
            showingDuplicates = false
            store.select(filter: filter)
        case .duplicates:
            showingDuplicates = true
        }
    }

    private var limitedBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundStyle(.orange)
            Text(loc("limited_banner"))
                .font(.footnote)
                .foregroundStyle(.primary)
            Spacer(minLength: 4)
            Button(loc("limited_manage")) {
                store.presentLimitedPicker()
            }
            .font(.footnote.weight(.semibold))
            .tint(theme.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassBackground(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 20)
        .frame(maxWidth: 700)
    }

    // MARK: Pile de cartes

    private var cardStack: some View {
        ZStack {
            if !store.hasLoaded || store.isLoading {
                VStack(spacing: 14) {
                    ProgressView().controlSize(.large)
                    Text(loc("loading")).foregroundStyle(.secondary)
                }
            } else if store.current == nil {
                finishedView
            } else {
                ForEach(Array(store.upcoming.enumerated().reversed()), id: \.element.localIdentifier) { i, asset in
                    let isTop = i == 0
                    MediaCard(asset: asset, isTop: isTop)
                        .overlay { if isTop { StampOverlay(offset: offset, threshold: threshold) } }
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
        .overlay {
            if store.isSwipeLocked(isPro: purchases.isPro) && !store.isLoading {
                lockedView
            }
        }
    }

    // MARK: Limite gratuite

    private var isLocked: Bool { store.isSwipeLocked(isPro: purchases.isPro) }

    private var lockedView: some View {
        VStack(spacing: 14) {
            Image(systemName: "lock.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.yellow)
                .frame(width: 76, height: 76)
                .glassBackground(in: Circle())
            Text(loc("limit_reached_title"))
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(loc("limit_reached_text", AppConfig.freeSwipeLimit))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showPaywall = true
            } label: {
                Text(loc("unlock_button"))
                    .font(.headline)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(theme.gradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(26)
        .glassBackground(in: RoundedRectangle(cornerRadius: 30, style: .continuous))
        .padding(.horizontal, 32)
    }

    private var freeSwipesBanner: some View {
        Button {
            showPaywall = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "crown.fill").foregroundStyle(.yellow)
                Text(loc("free_swipes_left", store.freeSwipesLeft))
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer(minLength: 4)
                Text(loc("go_pro"))
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(theme.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassBackground(in: Capsule(), interactive: true)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .frame(maxWidth: 700)
    }

    private var controls: some View {
        GlassGroup(spacing: 18) {
        HStack(spacing: 22) {
            roundButton(icon: "xmark", color: .red, size: 66, label: loc("action_delete")) { swipe(.trash) }
                .disabled(store.current == nil)
            roundButton(icon: "arrow.uturn.backward", color: .orange, size: 50, label: loc("action_undo")) { undo() }
                .disabled(!store.canUndo)
                .opacity(store.canUndo ? 1 : 0.4)
            roundButton(icon: "star.fill", color: .yellow, size: 50, label: loc("action_favorite")) { swipe(.favorite) }
                .disabled(store.current == nil)
            roundButton(icon: "heart.fill", color: .green, size: 66, label: loc("action_keep")) { swipe(.keep) }
                .disabled(store.current == nil)
        }
        }
    }

    private func roundButton(icon: String, color: Color, size: CGFloat, label: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .glassBackground(in: Circle(), interactive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var finishedView: some View {
        VStack(spacing: 16) {
            if store.deck.isEmpty {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 52))
                    .foregroundStyle(.secondary)
                Text(loc("nothing_to_sort"))
                    .font(.title2.bold())
            } else {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text(loc("all_sorted"))
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text(loc("session_summary", store.keptCount, store.trash.count))
                    .foregroundStyle(.secondary)
            }
            if !store.trash.isEmpty {
                Button(loc("empty_trash_button", L10n.bytes(store.trashBytes))) {
                    showTrash = true
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
            }
            Button(loc("choose_album_or_month")) {
                showSourcePicker = true
            }
            .buttonStyle(.bordered)
            Button(loc("review_from_newest")) {
                refreshSpins += 1
                store.refreshToNewest()
            }
            .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding(28)
        .glassBackground(in: RoundedRectangle(cornerRadius: 32, style: .continuous))
        .padding(.horizontal, 8)
    }

    // MARK: Gestes

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard !isAnimatingOut, store.current != nil, !isLocked else { return }
                offset = value.translation
                let x = value.translation.width
                let y = value.translation.height
                let newZone: Int
                if abs(x) >= abs(y) {
                    newZone = x > threshold ? 1 : (x < -threshold ? -1 : 0)
                } else {
                    newZone = y < -threshold ? 2 : 0
                }
                if newZone != zone { zone = newZone }
            }
            .onEnded { value in
                guard !isAnimatingOut, store.current != nil else { return }
                if isLocked {
                    resetCard()
                    showPaywall = true
                    return
                }
                let x = value.translation.width
                let y = value.translation.height
                let projectedX = value.predictedEndTranslation.width
                let projectedY = value.predictedEndTranslation.height
                if abs(x) >= abs(y) {
                    if x > threshold || projectedX > 500 {
                        swipe(.keep)
                    } else if x < -threshold || projectedX < -500 {
                        swipe(.trash)
                    } else {
                        resetCard()
                    }
                } else if y < -threshold || projectedY < -600 {
                    swipe(.favorite)
                } else {
                    resetCard()
                }
                zone = 0
            }
    }

    private func resetCard() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) { offset = .zero }
    }

    private func swipe(_ decision: SwipeDecision) {
        guard store.current != nil, !isAnimatingOut else { return }
        if isLocked {
            showPaywall = true
            return
        }
        isAnimatingOut = true
        let target: CGSize
        switch decision {
        case .keep: target = CGSize(width: 650, height: offset.height + 60)
        case .trash: target = CGSize(width: -650, height: offset.height + 60)
        case .favorite: target = CGSize(width: offset.width, height: -1000)
        }
        withAnimation(.easeIn(duration: 0.22)) {
            offset = target
        } completion: {
            store.decide(decision)
            offset = .zero
            isAnimatingOut = false
            // 100e swipe atteint : on propose la version illimitée
            if isLocked { showPaywall = true }
        }
    }

    private func undo() {
        guard let last = store.history.last, !isAnimatingOut else { return }
        store.undo()
        // La carte revient du côté où elle est partie
        switch last.decision {
        case .keep: offset = CGSize(width: 650, height: 60)
        case .trash: offset = CGSize(width: -650, height: 60)
        case .favorite: offset = CGSize(width: 0, height: -1000)
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(20))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) { offset = .zero }
        }
    }
}
