//
//  AppConfig.swift
//  ⚠️ Les réglages à personnaliser avant de publier l'app (voir README, partie 6).
//

import Foundation

nonisolated enum AppConfig {

    // MARK: À remplir avant publication

    /// Adresse web de ta politique de confidentialité (ex : "https://www.notion.so/…").
    /// Laisse vide pour masquer le lien dans les Réglages.
    static let privacyPolicyURL = ""

    /// Ton adresse e-mail de contact (ex : "swipephotos.app@gmail.com").
    /// Laisse vide pour masquer le bouton « Contacter ».
    static let supportEmail = ""

    /// Adresse qui reçoit les idées et signalements de bugs (onglet « Idées »).
    /// ⚠️ Remplace ce placeholder par ta vraie adresse.
    static let feedbackEmail = "ton.email@exemple.com"

    /// L'identifiant numérique de l'app sur l'App Store (visible dans App Store Connect,
    /// « Identifiant Apple », ex : "6740000000"). Sert au bouton « Noter l'app ».
    static let appStoreID = ""

    // MARK: Achat intégré (version Pro)

    /// Identifiant de l'achat intégré (non consommable, à vie) à créer dans App Store Connect.
    /// ⚠️ Placeholder : remplace-le par ton identifiant définitif (ex : "com.enzobataille.swipephotos.unlimited").
    /// Le prix (4,99 €) se règle uniquement dans App Store Connect, jamais dans le code.
    static let proProductID = "com.monapp.unlimited"

    /// Nombre de swipes gratuits (garder, supprimer ou favori) avant de devoir passer à la version illimitée.
    static let freeSwipeLimit = 100

    // MARK: Détection des photos similaires

    /// Deux photos prises à moins de X secondes d'intervalle sont comparées.
    static let burstWindow: TimeInterval = 90

    /// Seuil de ressemblance (plus petit = plus strict). 0,45 convient à la plupart des cas.
    static let similarityThreshold: Float = 0.45
}
