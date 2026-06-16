//
//  RouteAlertNotificationManager.swift
//  ttc-route-alerts
//

import Foundation
import UserNotifications

enum RouteAlertNotificationManager {
    static let seenNotificationKeysKey = "seenRouteAlertNotificationKeys"

    struct RouteAlertNotification {
        let key: String
        let route: TTCAlertRoute
        let alert: TTCAlert
        let severity: AlertSeverity
    }

    static func configureForegroundNotifications() {
        UNUserNotificationCenter.current().delegate = LocalNotificationDelegate.shared
    }

    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound, .badge])
            } catch {
                #if DEBUG
                print("Could not request notification permission: \(error.localizedDescription)")
                #endif
                return false
            }
        @unknown default:
            return false
        }
    }

    @discardableResult
    static func scheduleRouteAlertNotification(
        _ routeAlertNotification: RouteAlertNotification
    ) async -> Bool {
        let content = UNMutableNotificationContent()
        content.title = "TTC Route Alert"
        content.body = notificationBody(for: routeAlertNotification)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: routeAlertNotification.key,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            #if DEBUG
            print("Could not schedule route alert notification: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    static func newAlertNotifications(
        for route: TTCAlertRoute,
        matchingAlerts: [TTCAlert]
    ) -> [RouteAlertNotification] {
        let previouslySeenKeys = Set(savedNotificationKeys())
        var currentRouteKeys: Set<String> = []
        var keysSeenDuringThisRefresh: Set<String> = []
        var newNotifications: [RouteAlertNotification] = []

        for alert in matchingAlerts {
            let severity = AlertSeverity.forAlertText(alert.text)

            guard severity != .normal else {
                continue
            }

            let key = notificationKey(for: route, alert: alert, severity: severity)
            currentRouteKeys.insert(key)

            guard keysSeenDuringThisRefresh.insert(key).inserted else {
                continue
            }

            if !previouslySeenKeys.contains(key) {
                newNotifications.append(
                    RouteAlertNotification(
                        key: key,
                        route: route,
                        alert: alert,
                        severity: severity
                    )
                )
            }
        }

        markCurrentAlertKeysAsSeen(for: route, currentRouteKeys: currentRouteKeys)
        return newNotifications
    }

    static func notificationKey(
        for route: TTCAlertRoute,
        alert: TTCAlert,
        severity: AlertSeverity
    ) -> String {
        let normalizedAlertText = TTCAlertsService.normalizedAlertText(alert.text)
        let alertRouteIDs = alert.routeIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "|")
        let alertIdentity = "\(normalizedAlertText)|\(alertRouteIDs)"

        return [
            routeKeyPrefix(for: route),
            severityKey(for: severity),
            stableHash(for: alertIdentity)
        ]
        .joined(separator: "-")
    }

    static func notificationBody(for routeAlertNotification: RouteAlertNotification) -> String {
        let routeTitle = routeTitle(for: routeAlertNotification.route)
        let alertSummary = shortAlertSummary(for: routeAlertNotification.alert.text)

        return "\(routeTitle) has a \(routeAlertNotification.severity.rawValue): \(alertSummary)"
    }

    static func resetSeenAlertNotificationKeysForTesting() {
        UserDefaults.standard.removeObject(forKey: seenNotificationKeysKey)
    }

    private static func markCurrentAlertKeysAsSeen(for route: TTCAlertRoute, currentRouteKeys: Set<String>) {
        let prefix = "\(routeKeyPrefix(for: route))-"
        var keys = Set(savedNotificationKeys())

        keys = keys.filter { !$0.hasPrefix(prefix) }
        keys.formUnion(currentRouteKeys)

        if keys.count > 100 {
            keys = Set(keys.sorted().suffix(100))
        }

        UserDefaults.standard.set(Array(keys).sorted(), forKey: seenNotificationKeysKey)
    }

    private static func savedNotificationKeys() -> [String] {
        UserDefaults.standard.stringArray(forKey: seenNotificationKeysKey) ?? []
    }

    private static func routeKeyPrefix(for route: TTCAlertRoute) -> String {
        let routeIdentity = route.id.uuidString.isEmpty ? route.displayName : route.id.uuidString

        return "route-\(stableHash(for: routeIdentity))"
    }

    private static func severityKey(for severity: AlertSeverity) -> String {
        severity.rawValue
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func shortAlertSummary(for alertText: String) -> String {
        let cleanedText = alertText
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")

        guard cleanedText.count > 120 else {
            return cleanedText
        }

        let endIndex = cleanedText.index(cleanedText.startIndex, offsetBy: 117)
        return "\(cleanedText[..<endIndex])..."
    }

    private static func stableHash(for text: String) -> String {
        var hash: UInt64 = 5381

        for byte in text.utf8 {
            hash = ((hash << 5) &+ hash) &+ UInt64(byte)
        }

        return String(hash, radix: 16)
    }

    static func routeTitle(for route: TTCAlertRoute) -> String {
        guard let routeType = route.routeType,
              let routeNumber = route.routeNumber,
              !routeNumber.isEmpty else {
            return route.name
        }

        if routeType == .subway {
            return "Subway Line \(routeNumber)"
        } else {
            return "\(routeType.rawValue) \(routeNumber)"
        }
    }
}

private final class LocalNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LocalNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }
}
