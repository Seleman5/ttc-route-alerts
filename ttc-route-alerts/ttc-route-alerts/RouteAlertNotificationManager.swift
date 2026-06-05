//
//  RouteAlertNotificationManager.swift
//  ttc-route-alerts
//

import Foundation
import UserNotifications

enum RouteAlertNotificationManager {
    private static let sentNotificationKeysKey = "sentRouteAlertNotificationKeys"

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
                print("Could not request notification permission: \(error.localizedDescription)")
                return false
            }
        @unknown default:
            return false
        }
    }

    @discardableResult
    static func scheduleRouteAlertNotification(
        for route: TTCAlertRoute,
        severity: AlertSeverity,
        identifier: String
    ) async -> Bool {
        guard !hasRecentlySentNotification(identifier: identifier) else {
            return false
        }

        let content = UNMutableNotificationContent()
        content.title = "TTC Route Alert"
        content.body = "\(routeTitle(for: route)) has a \(severity.rawValue)"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )

        do {
            try await UNUserNotificationCenter.current().add(request)
            rememberSentNotification(identifier: identifier)
            return true
        } catch {
            print("Could not schedule route alert notification: \(error.localizedDescription)")
            return false
        }
    }

    static func notificationKey(
        for route: TTCAlertRoute,
        severity: AlertSeverity,
        alerts: [TTCAlert]
    ) -> String {
        let alertText = alerts
            .map { TTCAlertsService.normalizedAlertText($0.text) }
            .sorted()
            .joined(separator: "|")
        let routeID = route.routeID ?? route.routeNumber ?? route.name
        let routeNumber = route.routeNumber ?? route.name

        return [
            routeID,
            routeNumber,
            severity.rawValue,
            stableHash(for: alertText)
        ]
        .joined(separator: "-")
    }

    static func hasRecentlySentNotification(identifier: String) -> Bool {
        savedNotificationKeys().contains(identifier)
    }

    private static func rememberSentNotification(identifier: String) {
        var keys = savedNotificationKeys()
        keys.append(identifier)

        if keys.count > 100 {
            keys = Array(keys.suffix(100))
        }

        UserDefaults.standard.set(keys, forKey: sentNotificationKeysKey)
    }

    private static func savedNotificationKeys() -> [String] {
        UserDefaults.standard.stringArray(forKey: sentNotificationKeysKey) ?? []
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
