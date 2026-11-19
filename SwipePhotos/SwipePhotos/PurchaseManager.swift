//
//  PurchaseManager.swift
//  Achat intégré « Swipe Photos Pro » (StoreKit 2) : achat unique, pas d'abonnement.
//
//  Version gratuite : AppConfig.freeSwipeLimit swipes.
//  Version illimitée : achat unique à vie (prix réglé dans App Store Connect).
//

import Foundation
import Combine
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var product: Product?
    @Published private(set) var isPro: Bool
    @Published private(set) var isPurchasing = false
    @Published private(set) var hasLoadedProducts = false
    @Published var errorMessage: String?

    private let cacheKey = "pro.unlocked"
    private var updatesTask: Task<Void, Never>?

    init() {
        isPro = UserDefaults.standard.bool(forKey: cacheKey)
        // Écoute les achats faits ailleurs (autre appareil, remboursement, « Demander à acheter »…)
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                if case .verified(let transaction) = update {
                    await transaction.finish()
                }
                await self?.refreshEntitlements()
            }
        }
        Task { await load() }
    }

    /// Prix affiché, fourni par l'App Store dans la devise de l'utilisateur (ex : "4,99 €").
    /// nil tant que le produit n'est pas chargé : le prix n'est jamais écrit en dur.
    var priceText: String? { product?.displayPrice }

    func load() async {
        do {
            product = try await Product.products(for: [AppConfig.proProductID]).first
        } catch {
            product = nil
        }
        hasLoadedProducts = true
        await refreshEntitlements()
    }

    func refreshEntitlements() async {
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == AppConfig.proProductID,
               transaction.revocationDate == nil {
                unlocked = true
            }
        }
        #if DEBUG
        // En test, on garde le déblocage manuel fait depuis l'écran Pro
        if !unlocked && UserDefaults.standard.bool(forKey: "pro.debugUnlocked") { unlocked = true }
        #endif
        setPro(unlocked)
    }

    func purchase() async {
        if product == nil { await load() }
        guard let product else {
            errorMessage = loc("paywall_unavailable")
            return
        }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    setPro(true)
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restore() async {
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refreshEntitlements()
        if !isPro { errorMessage = loc("paywall_nothing_to_restore") }
    }

    #if DEBUG
    /// Uniquement pendant les tests depuis Xcode : débloque Pro sans payer.
    func debugUnlock() {
        UserDefaults.standard.set(true, forKey: "pro.debugUnlocked")
        setPro(true)
    }

    /// Uniquement pendant les tests : revient à la version gratuite.
    /// (Les faux achats StoreKit se suppriment dans Xcode : Debug → StoreKit → Manage Transactions.)
    func debugReset() async {
        UserDefaults.standard.set(false, forKey: "pro.debugUnlocked")
        setPro(false)
        await refreshEntitlements()
    }
    #endif

    private func setPro(_ value: Bool) {
        isPro = value
        UserDefaults.standard.set(value, forKey: cacheKey)
    }
}
