//
//  SettingsView.swift
//  ttc-route-alerts
//

import SwiftUI

struct SettingsView: View {
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage(RefreshPreference.storageKey) private var refreshPreference = RefreshPreference.manualOnly.rawValue
    @AppStorage(SavedRouteArrivalPreviewPreference.storageKey) private var savedRouteArrivalPreviewEnabled = true
    @State private var notificationMessage: String?
    @State private var isRevertingNotificationsToggle = false

    private let privacyPolicyURL = URL(string: "https://seleman5.github.io/ttc-route-alerts/privacy.html")!

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
                    arrivalsSection
                    appStatusSection
                    aboutSection
                }
                .padding(.horizontal, AppDesign.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 28)
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
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeaderView(title: "Notifications", systemImage: "bell.badge", tint: ttcRed)

            Toggle(isOn: $notificationsEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Route alert notifications")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Get notified when a refreshed saved route has an alert.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Notifications are sent only for saved routes with matching TTC alerts after an app refresh or an allowed background refresh.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if let notificationMessage {
                SettingsMessageView(message: notificationMessage)
            }
        }
        .settingsCardStyle()
    }

    var refreshSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeaderView(title: "Refresh", systemImage: "arrow.clockwise", tint: ttcRed)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Auto refresh")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Choose how often the app checks while it is open.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(1)

                Spacer(minLength: 8)

                Picker("Refresh alerts", selection: $refreshPreference) {
                    ForEach(RefreshPreference.allCases) { preference in
                        Text(preference.rawValue)
                            .tag(preference.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Text("Background refresh uses the same preference as a request to iOS, but iOS decides the actual timing based on battery, network, and usage patterns.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .settingsCardStyle()
    }

    var arrivalsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HomeSectionHeaderView(title: "Arrivals", systemImage: "clock.fill", tint: ttcRed)

            Toggle(isOn: $savedRouteArrivalPreviewEnabled) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Saved route arrival preview")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text("Show a quick live arrival estimate on bus and streetcar route cards.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Stop detail screens still show full live arrivals even when this preview is off.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .settingsCardStyle()
    }

    var appStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeaderView(title: "App Status", systemImage: "checklist", tint: ttcRed)

            SettingsInfoRow(title: "Notifications", value: notificationsEnabled ? "On" : "Off")
            SettingsInfoRow(title: "Refresh", value: refreshPreference)
            SettingsInfoRow(title: "Route arrivals", value: savedRouteArrivalPreviewEnabled ? "On" : "Off")

            Text("Manual refresh and pull-to-refresh are always available from the route list.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .settingsCardStyle()
    }

    var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeaderView(title: "About", systemImage: "info.circle", tint: ttcRed)

            SettingsInfoRow(title: "App", value: "TTC Route Alerts")
            SettingsInfoRow(title: "Description", value: "Track saved TTC routes and see matching service alerts.")
            SettingsInfoRow(title: "Data Source", value: "TTC GTFS-Realtime alerts")
            SettingsInfoRow(title: "Disclaimer", value: "Independent app. Not affiliated with, endorsed by, sponsored by, or operated by the TTC. Public transit data may not always be accurate or available.")
            SettingsLinkRow(title: "Privacy Policy", value: "Open hosted privacy policy", url: privacyPolicyURL)

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

enum SavedRouteArrivalPreviewPreference {
    static let storageKey = "savedRouteArrivalPreviewEnabled"
}

enum RefreshPreference: String, CaseIterable, Identifiable {
    static let storageKey = "refreshPreference"

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

struct SettingsLinkRow: View {
    let title: String
    let value: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack(alignment: .center, spacing: 12) {
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
                .layoutPriority(1)

                Spacer(minLength: 8)

                Image(systemName: "arrow.up.right.square")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Opens in Safari or the default browser.")
    }
}

struct SettingsMessageView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppDesign.insetBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
            .accessibilityLabel(message)
    }
}

private extension View {
    func settingsCardStyle() -> some View {
        appCardStyle()
    }
}
