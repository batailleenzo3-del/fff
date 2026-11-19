//
//  PaywallView.swift
//  Écran « Swipe Photos Pro » : achat unique pour des suppressions illimitées.
//

import SwiftUI
import Combine
import StoreKit

struct PaywallView: View {
    @ObservedObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 22) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.yellow)
                            .frame(width: 120, height: 120)
                            .glassBackground(in: Circle())
                            .padding(.top, 12)

                        VStack(spacing: 8) {
                            Text(loc("paywall_title"))
                                .font(.system(.largeTitle, design: .rounded, weight: .heavy))
                                .multilineTextAlignment(.center)
                            Text(loc("paywall_subtitle", AppConfig.freeDeletionLimit))
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            feature("infinity", loc("paywall_feature_unlimited"))
                            feature("square.on.square", loc("paywall_feature_duplicates"))
                            feature("film.stack", loc("paywall_feature_videos"))
                            feature("heart.fill", loc("paywall_feature_support"))
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassBackground(in: RoundedRectangle(cornerRadius: 24, style: .continuous))

                        if purchases.isPro {
                            Label(loc("pro_active_title"), systemImage: "checkmark.seal.fill")
                                .font(.headline)
                                .foregroundStyle(.green)
                        } else {
                            Button {
                                Task {
                                    await purchases.purchase()
                                    if purchases.isPro { dismiss() }
                                }
                            } label: {
                                HStack {
                                    if purchases.isPurchasing { ProgressView().tint(.white) }
                                    Text(loc("paywall_buy", purchases.priceText))
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 17)
                                .background(LinearGradient.brand, in: Capsule())
                                .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            .disabled(purchases.isPurchasing)

                            Text(loc("paywall_one_time"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)

                            Button(loc("restore_purchases")) {
                                Task { await purchases.restore() }
                            }
                            .font(.footnote.weight(.semibold))
                            .tint(.pink)

                            #if DEBUG
                            Button("🧪 Débloquer Pro (test uniquement)") {
                                purchases.debugUnlock()
                                dismiss()
                            }
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            #endif
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("later")) { dismiss() }
                }
            }
            .alert(loc("paywall_error_title"), isPresented: Binding(
                get: { purchases.errorMessage != nil },
                set: { if !$0 { purchases.errorMessage = nil } }
            )) {
                Button(loc("ok"), role: .cancel) { purchases.errorMessage = nil }
            } message: {
                Text(purchases.errorMessage ?? "")
            }
        }
    }

    private func feature(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.pink)
                .frame(width: 30)
            Text(text)
                .font(.body)
        }
    }
}
