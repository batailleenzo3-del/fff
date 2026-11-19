//
//  Localization.swift
//  Textes dans la langue de l'iPhone (français, anglais, espagnol, allemand, italien).
//
//  Usage dans les écrans : loc("trash_title")  ou  loc("to_sort", 42)
//  Les traductions sont dans Strings.swift.
//

import Foundation

nonisolated enum L10n {
    static let supportedLanguages = ["fr", "en", "es", "de", "it"]

    /// Langue utilisée par l'app (la première langue de l'iPhone qu'on sait parler, sinon anglais).
    static let language: String = {
        for preferred in Locale.preferredLanguages {
            let code = String(preferred.prefix(2))
            if supportedLanguages.contains(code) { return code }
        }
        return "en"
    }()

    /// Texte traduit. Les {0}, {1}… sont remplacés par les valeurs données.
    static func t(_ key: String, _ args: CustomStringConvertible...) -> String {
        var text = Strings.table(for: language)[key] ?? Strings.en[key] ?? key
        for (index, value) in args.enumerated() {
            text = text.replacingOccurrences(of: "{\(index)}", with: value.description)
        }
        return text
    }

    /// "1,2 Go", "350 Mo"…
    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    /// Titre d'un mois : "Novembre 2026"
    static func monthTitle(year: Int, month: Int) -> String {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let date = Calendar.current.date(from: components) else { return "\(month)/\(year)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language)
        formatter.setLocalizedDateFormatFromTemplate("MMMM yyyy")
        return formatter.string(from: date).capitalized
    }

    /// Durée d'une vidéo : "0:42"
    static func duration(_ seconds: Double) -> String {
        let total = Int(seconds.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

/// Raccourci utilisé dans les écrans.
func loc(_ key: String, _ args: CustomStringConvertible...) -> String {
    var text = L10n.t(key)
    for (index, value) in args.enumerated() {
        text = text.replacingOccurrences(of: "{\(index)}", with: value.description)
    }
    return text
}
