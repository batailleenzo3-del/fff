//
//  FeedbackView.swift
//  Onglet « Idées & bugs » : les utilisateurs proposent une amélioration ou signalent un bug.
//  Envoi sans serveur : ouverture de l'app Mail pré-remplie (adresse : AppConfig.feedbackEmail).
//

import SwiftUI
import UIKit

/// Type de message.
enum FeedbackCategory: String, CaseIterable, Identifiable {
    case feature, bug, design, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feature: return loc("cat_feature")
        case .bug: return loc("cat_bug")
        case .design: return loc("cat_design")
        case .other: return loc("cat_other")
        }
    }

    var icon: String {
        switch self {
        case .feature: return "sparkles"
        case .bug: return "ladybug.fill"
        case .design: return "paintpalette.fill"
        case .other: return "bubble.left.fill"
        }
    }

    var color: Color {
        switch self {
        case .feature: return .yellow
        case .bug: return .red
        case .design: return .purple
        case .other: return .blue
        }
    }

    var placeholder: String {
        switch self {
        case .feature: return loc("feedback_placeholder_feature")
        case .bug: return loc("feedback_placeholder_bug")
        case .design: return loc("feedback_placeholder_design")
        case .other: return loc("feedback_placeholder_other")
        }
    }
}

struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// Le brouillon est gardé même si on ferme l'écran.
    @AppStorage("feedback.draft") private var draft = ""
    @AppStorage("feedback.category") private var categoryRaw = FeedbackCategory.feature.rawValue
    @State private var includeDeviceInfo = true
    @State private var showNoMailAlert = false
    @State private var sent = false
    @FocusState private var editorFocused: Bool

    private var category: FeedbackCategory {
        FeedbackCategory(rawValue: categoryRaw) ?? .feature
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if sent {
                    thanksView
                } else {
                    form
                }
            }
            .navigationTitle(loc("feedback_title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(loc("close")) { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(loc("done")) { editorFocused = false }
                }
            }
            .alert(loc("feedback_no_mail_title"), isPresented: $showNoMailAlert) {
                Button(loc("feedback_copy")) {
                    UIPasteboard.general.string = "\(AppConfig.feedbackEmail)\n\n\(subject)\n\n\(messageBody)"
                }
                Button(loc("ok"), role: .cancel) {}
            } message: {
                Text(loc("feedback_no_mail_text", AppConfig.feedbackEmail))
            }
        }
    }

    // MARK: Formulaire

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(loc("feedback_header"))
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text(loc("feedback_intro"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Catégories
                VStack(alignment: .leading, spacing: 10) {
                    Text(loc("feedback_category"))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                        ForEach(FeedbackCategory.allCases) { item in
                            categoryButton(item)
                        }
                    }
                }

                // Message
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $draft)
                        .focused($editorFocused)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(10)
                    if draft.isEmpty {
                        Text(category.placeholder)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 18)
                            .allowsHitTesting(false)
                    }
                }
                .glassBackground(in: RoundedRectangle(cornerRadius: 20, style: .continuous))

                Toggle(isOn: $includeDeviceInfo) {
                    Label(loc("feedback_device_info"), systemImage: "iphone")
                        .font(.subheadline)
                }
                .tint(.pink)

                // Envoi
                Button {
                    send()
                } label: {
                    Label(loc("feedback_send"), systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(canSend ? AnyShapeStyle(LinearGradient.brand) : AnyShapeStyle(Color.gray.opacity(0.4)),
                                    in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .disabled(!canSend)

                ShareLink(item: "\(subject)\n\n\(messageBody)") {
                    Label(loc("feedback_share"), systemImage: "square.and.arrow.up")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .tint(.pink)
                .disabled(!canSend)
            }
            .padding(20)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func categoryButton(_ item: FeedbackCategory) -> some View {
        let selected = item == category
        return Button {
            categoryRaw = item.rawValue
        } label: {
            HStack(spacing: 8) {
                Image(systemName: item.icon)
                    .foregroundStyle(item.color)
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer(minLength: 0)
                if selected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.pink)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .glassBackground(in: RoundedRectangle(cornerRadius: 16, style: .continuous),
                             tint: selected ? item.color.opacity(0.25) : nil,
                             interactive: true)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(selected ? Color.pink : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var thanksView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.text.square.fill")
                .font(.system(size: 52))
                .foregroundStyle(LinearGradient.brand)
                .frame(width: 120, height: 120)
                .glassBackground(in: Circle())
            Text(loc("feedback_thanks_title"))
                .font(.system(.title, design: .rounded, weight: .bold))
            Text(loc("feedback_thanks_text"))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button(loc("close")) { dismiss() }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
        }
        .padding(32)
    }

    // MARK: Envoi

    private var subject: String {
        "[Swipe Photos] \(category.title)"
    }

    private var messageBody: String {
        var text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        if includeDeviceInfo {
            text += "\n\n—\n" + Self.deviceInfo()
        }
        return text
    }

    private func send() {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = AppConfig.feedbackEmail
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: messageBody)
        ]
        guard let url = components.url else {
            showNoMailAlert = true
            return
        }
        openURL(url) { accepted in
            if accepted {
                draft = ""
                sent = true
            } else {
                showNoMailAlert = true
            }
        }
    }

    /// Infos techniques utiles pour corriger un bug (aucune donnée personnelle).
    private static func deviceInfo() -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        var systemInfo = utsname()
        uname(&systemInfo)
        let model = withUnsafeBytes(of: &systemInfo.machine) { raw in
            String(decoding: raw.prefix(while: { $0 != 0 }), as: UTF8.self)
        }
        return """
        App: \(version) (\(build))
        iOS: \(UIDevice.current.systemVersion)
        Device: \(model)
        Language: \(L10n.language)
        """
    }
}
