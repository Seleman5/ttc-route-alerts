//
//  SettingsView.swift
//  ttc-route-alerts
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("refreshPreference") private var refreshPreference = RefreshPreference.manualOnly.rawValue
    @State private var notificationMessage: String?
    @State private var isRevertingNotificationsToggle = false

    let ttcRed: Color
    let appBackground: Color

    var body: some View {
        ZStack {
            appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    notificationsSection
                    refreshSection
                    aboutSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .tint(ttcRed)
        .onChange(of: notificationsEnabled) { _, isEnabled in
            handleNotificationsToggle(isEnabled)
        }
    }

    var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)

            Toggle("Route alert notifications", isOn: $notificationsEnabled)

            Text("When enabled, this app can notify you after you refresh and one of your saved routes has an alert.")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let notificationMessage {
                Text(notificationMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .settingsCardStyle()
    }

    var refreshSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refresh Preferences")
                .font(.headline)

            Picker("Refresh alerts", selection: $refreshPreference) {
                ForEach(RefreshPreference.allCases) { preference in
                    Text(preference.rawValue)
                        .tag(preference.rawValue)
                }
            }
            .pickerStyle(.menu)

            Text("Automatic refresh runs only while the app is open.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .settingsCardStyle()
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("About")
                .font(.headline)

            SettingsInfoRow(title: "App", value: "TTC Route Alerts")
            SettingsInfoRow(title: "Description", value: "Track saved TTC routes and see matching service alerts.")
            SettingsInfoRow(title: "Data Source", value: "TTC GTFS-Realtime alerts")

            if let appVersionText {
                SettingsInfoRow(title: "Version", value: appVersionText)
            }
        }
        .settingsCardStyle()
    }

    var appVersionText: String? {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String

        if let version, let build {
            return "\(version) (\(build))"
        } else {
            return version ?? build
        }
    }

    func handleNotificationsToggle(_ isEnabled: Bool) {
        if isRevertingNotificationsToggle {
            isRevertingNotificationsToggle = false
            return
        }

        if isEnabled {
            Task {
                let permissionGranted = await RouteAlertNotificationManager.requestPermission()

                await MainActor.run {
                    if permissionGranted {
                        notificationMessage = "Notifications are on."
                    } else {
                        isRevertingNotificationsToggle = true
                        notificationsEnabled = false
                        notificationMessage = "Notification permission was denied. You can enable it later in iOS Settings."
                    }
                }
            }
        } else {
            notificationMessage = "Notifications are off."
        }
    }
}

enum RefreshPreference: String, CaseIterable, Identifiable {
    case manualOnly = "Manual only"
    case everyFiveMinutes = "Every 5 minutes"
    case everyFifteenMinutes = "Every 15 minutes"

    var id: String {
        rawValue
    }

    var refreshIntervalInSeconds: Double? {
        switch self {
        case .manualOnly:
            return nil
        case .everyFiveMinutes:
            return 5 * 60
        case .everyFifteenMinutes:
            return 15 * 60
        }
    }
}

struct SettingsInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private extension View {
    func settingsCardStyle() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
    }
}
