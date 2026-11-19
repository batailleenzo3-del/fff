//
//  SettingsView.swift
//  Réglages : version Pro, statistiques, tri, apparence, aide, à propos.
//

import SwiftUI
import Combine
import StoreKit
import UIKit

struct SettingsView: View {
    @ObservedObject var store: SwipeStore
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.requestReview) private var requestReview

    @AppStorage(SettingsKey.sortOrder) private var sortOrderRaw = SortOrder.newest.rawValue
    @AppStorage(SettingsKey.cycle) private var cycleRaw = CycleOption.day.rawValue
    @AppStorage(SettingsKey.appearance) private var appearanceRaw = AppearanceOption.system.rawValue
    @AppStorage(SettingsKey.haptics) private var hapticsEnabled = true
    @AppStorage(SettingsKey.videoMuted) private var videoMuted = true
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = true

    @State private var showPaywall = false
    @State private var showFeedback = false

    var body: some View {
        NavigationStack {
            Form {
                proSection

                Section {
                    NavigationLink {
                        StatsView(store: store)
                    } label: {
                        Label(loc("stats_title"), systemImage: "chart.bar.fill")
                    }
                }

                Section {
                    Picker(selection: $sortOrderRaw) {
                        ForEach(SortOrder.allCases) { order in
                            Text(order.title).tag(order.rawValue)
                        }
                    } label: {
                        Label(loc("settings_order"), systemImage: "arrow.up.arrow.down")
                    }
                    Picker(selection: $cycleRaw) {
                        ForEach(CycleOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    } label: {
                        Label(loc("settings_cycle"), systemImage: "clock.arrow.circlepath")
                    }
                } header: {
                    Text(loc("settings_sorting"))
                } footer: {
                    Text(loc("settings_cycle_footer"))
                }

                Section(loc("settings_appearance")) {
                    Picker(selection: $appearanceRaw) {
                        ForEach(AppearanceOption.allCases) { option in
                            Text(option.title).tag(option.rawValue)
                        }
                    } label: {
                        Label(loc("settings_theme"), systemImage: "circle.lefthalf.filled")
                    }
                    Toggle(isOn: $hapticsEnabled) {
                        Label(loc("settings_haptics"), systemImage: "hand.tap.fill")
                    }
                    Toggle(isOn: Binding(get: { !videoMuted }, set: { videoMuted = !$0 })) {
                        Label(loc("settings_video_sound"), systemImage: "speaker.wave.2.fill")
                    }
                }

                Section(loc("settings_help")) {
                    Button {
                        showFeedback = true
                    } label: {
                        Label(loc("feedback_title"), systemImage: "lightbulb.fill")
                    }
                    Button {
                        onboardingDone = false
                        dismiss()
                    } label: {
                        Label(loc("settings_tutorial"), systemImage: "questionmark.circle")
                    }
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                    } label: {
                        Label(loc("settings_photo_access"), systemImage: "lock.shield")
                    }
                }

                #if DEBUG
                Section {
                    LabeledContent("Swipes gratuits utilisés", value: "\(store.freeSwipesUsed) / \(AppConfig.freeSwipeLimit)")
                    LabeledContent("Version illimitée", value: purchases.isPro ? "Achetée" : "Non")
                    LabeledContent("Produit StoreKit", value: purchases.product?.displayPrice ?? "non chargé")
                    Button("Aller à 95 swipes (tester le paiement)") {
                        store.debugSetFreeSwipesUsed(AppConfig.freeSwipeLimit - 5)
                    }
                    Button("Remettre les swipes gratuits à 0") {
                        store.debugSetFreeSwipesUsed(0)
                    }
                    Button("Revenir à la version gratuite", role: .destructive) {
                        Task { await purchases.debugReset() }
                    }
                } header: {
                    Text("🧪 Mode test (invisible sur l'App Store)")
                } footer: {
                    Text("Pour effacer un faux achat : dans Xcode, menu Debug → StoreKit → Manage Transactions, sélectionne l'achat puis supprime-le.")
                }
                #endif

                Section(loc("settings_about")) {
                    Button {
                        rateApp()
                    } label: {
                        Label(loc("settings_rate"), systemImage: "star.bubble")
                    }
                    if !AppConfig.supportEmail.isEmpty,
                       let url = URL(string: "mailto:\(AppConfig.supportEmail)") {
                        Button {
                            openURL(url)
                        } label: {
                            Label(loc("settings_contact"), systemImage: "envelope")
                        }
                    }
                    if !AppConfig.privacyPolicyURL.isEmpty,
                       let url = URL(string: AppConfig.privacyPolicyURL) {
                        Button {
                            openURL(url)
                        } label: {
                            Label(loc("settings_privacy"), systemImage: "hand.raised.fill")
                        }
                    }
                    HStack {
                        Label(loc("settings_version"), systemImage: "info.circle")
                        Spacer()
                        Text(appVersion).foregroundStyle(.secondary)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppBackground())
            .tint(.pink)
            .navigationTitle(loc("settings_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(loc("done")) { dismiss() }
                }
            }
            .onChange(of: sortOrderRaw) { _, _ in store.reload() }
            .sheet(isPresented: $showPaywall) {
                PaywallView(purchases: purchases)
                    .appAppearance()
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
                    .appAppearance()
            }
        }
    }

    // MARK: Pro

    private var proSection: some View {
        Section {
            if purchases.isPro {
                HStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(.yellow)
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(loc("pro_active_title")).font(.headline)
                        Text(loc("pro_active_text")).font(.footnote).foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown.fill")
                            .font(.title2)
                            .foregroundStyle(.yellow)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(loc("pro_upgrade_title")).font(.headline).foregroundStyle(.primary)
                            Text(loc("free_swipes_left", store.freeSwipesLeft))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if let price = purchases.priceText {
                            Text(price)
                                .font(.subheadline.weight(.bold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(LinearGradient.brand, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.vertical, 4)
                }
                Button(loc("restore_purchases")) {
                    Task { await purchases.restore() }
                }
            }
        }
    }

    // MARK: Actions

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func rateApp() {
        if !AppConfig.appStoreID.isEmpty,
           let url = URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreID)?action=write-review") {
            openURL(url)
        } else {
            requestReview()
        }
    }
}

// MARK: - Statistiques

struct StatsView: View {
    @ObservedObject var store: SwipeStore

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(spacing: 6) {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .font(.system(size: 34))
                        .foregroundStyle(LinearGradient.brand)
                    Text(L10n.bytes(store.totalFreedBytes))
                        .font(.system(size: 44, weight: .heavy, design: .rounded))
                        .contentTransition(.numericText())
                    Text(loc("stats_freed"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .glassBackground(in: RoundedRectangle(cornerRadius: 28, style: .continuous))

                LazyVGrid(columns: columns, spacing: 12) {
                    statCard(value: store.totalSwiped, label: loc("stats_swiped"), icon: "hand.draw.fill", color: .purple)
                    statCard(value: store.totalDeletedCount, label: loc("stats_deleted"), icon: "trash.fill", color: .red)
                    statCard(value: store.totalKept, label: loc("stats_kept"), icon: "heart.fill", color: .green)
                    statCard(value: store.totalFavorited, label: loc("stats_favorites"), icon: "star.fill", color: .yellow)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(loc("stats_cycle_title")).font(.headline)
                    Text(loc("stats_cycle_text", store.reviewedCount, store.remaining))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: cycleProgress)
                        .tint(.pink)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .glassBackground(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .padding(16)
        }
        .background(AppBackground())
        .navigationTitle(loc("stats_title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cycleProgress: Double {
        let total = store.reviewedCount + store.remaining
        guard total > 0 else { return 0 }
        return Double(store.reviewedCount) / Double(total)
    }

    private func statCard(value: Int, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(.title, design: .rounded, weight: .bold))
                .contentTransition(.numericText())
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassBackground(in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
