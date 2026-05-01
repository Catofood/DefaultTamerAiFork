//
//  UpdateManager.swift
//  Default Tamer
//
//  Sparkle update integration with gentle reminders for background (LSUIElement) apps.
//

import Foundation
import Sparkle
import UserNotifications

private let kUpdateNotificationID = "com.defaulttamer.update-available"

@MainActor
class UpdateManager: NSObject, ObservableObject {
    @Published var isChecking = false

    // lazy so `self` is available when the closure runs, satisfying SPUStandardUserDriverDelegate.
    private(set) lazy var updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: self
    )

    var updater: SPUUpdater { updaterController.updater }

    func checkForUpdates(forced: Bool = false) {
        isChecking = true
        updaterController.checkForUpdates(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.isChecking = false
        }
    }
}

// MARK: - Gentle Reminders (SPUStandardUserDriverDelegate)

extension UpdateManager: SPUStandardUserDriverDelegate {

    nonisolated var supportsGentleScheduledUpdateReminders: Bool { true }

    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        // handleShowingUpdate == false when the app is in the background and Sparkle
        // won't show its own UI — we need to nudge the user ourselves.
        guard !handleShowingUpdate else { return }

        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Default Tamer"
            content.title = "\(appName) \(update.displayVersionString) is available"
            content.body = "Open Default Tamer settings to install the update."

            let request = UNNotificationRequest(
                identifier: kUpdateNotificationID,
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }

    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [kUpdateNotificationID])
    }

    nonisolated func standardUserDriverWillFinishUpdateSession() {
        UNUserNotificationCenter.current()
            .removeDeliveredNotifications(withIdentifiers: [kUpdateNotificationID])
    }
}

// MARK: - CheckForUpdatesViewModel

final class CheckForUpdatesViewModel: ObservableObject {
    @Published var canCheckForUpdates = false

    var updater: SPUUpdater? {
        didSet {
            observation = updater?.publisher(for: \.canCheckForUpdates)
                .assign(to: \.canCheckForUpdates, on: self)
        }
    }

    private var observation: Any?
}
