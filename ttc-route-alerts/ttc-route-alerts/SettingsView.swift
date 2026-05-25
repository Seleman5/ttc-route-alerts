//
//  SettingsView.swift
//  ttc-route-alerts
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("refreshPreference") private var refreshPreference = RefreshPreference.manualOnly.rawValue

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
    }

    var notificationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notifications")
                .font(.headline)

            Toggle("Route alert notifications", isOn: $notificationsEnabled)

            Text("Notification permission will be added in a future update.")
                .font(.caption)
                .foregroundStyle(.secondary)
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

            Text("Automatic refresh is not active yet.")
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
}

enum RefreshPreference: String, CaseIterable, Identifiable {
    case manualOnly = "Manual only"
    case everyFiveMinutes = "Every 5 minutes"
    case everyFifteenMinutes = "Every 15 minutes"

    var id: String {
        rawValue
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
