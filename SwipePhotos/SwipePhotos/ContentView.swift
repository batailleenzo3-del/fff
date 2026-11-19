//
//  ContentView.swift
//  Écran racine : tutoriel → autorisation → écran de tri.
//

import SwiftUI
import Combine
import Photos
import UIKit

struct ContentView: View {
    @Environment(\.appTheme) private var theme
    @StateObject private var store = SwipeStore()
    @StateObject private var purchases = PurchaseManager()
    @AppStorage(SettingsKey.onboardingDone) private var onboardingDone = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack {
            AppBackground()

            if !onboardingDone {
                OnboardingView {
                    withAnimation(.snappy) { onboardingDone = true }
                }
                .transition(.opacity)
            } else {
                switch store.authorization {
                case .notDetermined:
                    PermissionView(store: store)
                case .denied, .restricted:
                    DeniedView()
                default:
                    SwipeScreen(store: store, purchases: purchases)
                }
            }
        }
        .appAppearance()
        .task {
            if store.isAuthorized && !store.hasLoaded { store.start() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                store.persistNow() // on garde la position exacte
            case .active:
                // Pas de rechargement : on reste sur la même photo
                // (sauf si le cycle de retour aux plus récentes est terminé).
                store.becameActive()
            default:
                break
            }
        }
    }
}

// MARK: - Autorisation

struct PermissionView: View {
    @Environment(\.appTheme) private var theme
    @ObservedObject var store: SwipeStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "photo.stack.fill")
                .font(.system(size: 64))
                .foregroundStyle(theme.gradient)
                .frame(width: 130, height: 130)
                .glassBackground(in: Circle())
            Text(loc("permission_title"))
                .font(.system(.title, design: .rounded, weight: .bold))
                .multilineTextAlignment(.center)
            Text(loc("permission_text"))
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
            Button {
                Task { await store.requestAccess() }
            } label: {
                Text(loc("permission_button"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(theme.gradient, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(maxWidth: 520)
    }
}

struct DeniedView: View {
    @Environment(\.appTheme) private var theme
    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
                .frame(width: 110, height: 110)
                .glassBackground(in: Circle())
            Text(loc("denied_title"))
                .font(.title2.bold())
            Text(loc("denied_text"))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(loc("open_settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(theme.primary)
        }
        .padding(32)
        .frame(maxWidth: 520)
    }
}

#Preview {
    ContentView()
}
