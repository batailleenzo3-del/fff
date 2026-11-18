//
//  Localization.swift
//  Textes en français ou en anglais selon la langue de l'iPhone.
//
//  Usage : tr("Bonjour", "Hello")
//

import Foundation

nonisolated enum L10n {
    /// true si l'iPhone est réglé en français.
    static let isFrench: Bool = {
        let language = Locale.preferredLanguages.first ?? "en"
        return language.hasPrefix("fr")
    }()

    static func tr(_ french: String, _ english: String) -> String {
        isFrench ? french : english
    }

    /// "1,2 Go", "350 Mo"… (format automatique selon la langue)
    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    /// Titre d'un mois : "Novembre 2026" / "November 2026"
    static func monthTitle(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return "\(month)/\(year)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: isFrench ? "fr_FR" : "en_US")
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date).capitalized
    }

    /// Durée d'une vidéo : "0:42", "12:05"
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Raccourci utilisé dans les écrans.
func tr(_ french: String, _ english: String) -> String {
    L10n.tr(french, english)
}
