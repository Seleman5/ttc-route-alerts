//
//  RouteAlertNotificationManager.swift
//  ttc-route-alerts
//

import Foundation
import UserNotifications

enum RouteAlertNotificationManager {
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

    static func scheduleRouteAlertNotification(
        for route: TTCAlertRoute,
        severity: AlertSeverity,
        identifier: String
    ) async {
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
        } catch {
            print("Could not schedule route alert notification: \(error.localizedDescription)")
        }
    }

    static func notificationKey(
        for route: TTCAlertRoute,
        severity: AlertSeverity,
        alerts: [TTCAlert]
    ) -> String {
        let alertText = alerts.map(\.text).joined(separator: "|")
        let routeID = route.routeID ?? route.id.uuidString
        let routeNumber = route.routeNumber ?? route.name

        return [
            routeID,
            routeNumber,
            severity.rawValue,
            String(alertText.hashValue)
        ]
        .joined(separator: "-")
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
