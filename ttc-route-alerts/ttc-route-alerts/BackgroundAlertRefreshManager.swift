//
//  BackgroundAlertRefreshManager.swift
//  ttc-route-alerts
//

import BackgroundTasks
import Foundation

enum BackgroundAlertRefreshManager {
    static let taskIdentifier = "com.sully.ttc-route-alerts.refresh"

    static func registerBackgroundRefresh() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: taskIdentifier, using: nil) { task in
            guard let appRefreshTask = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }

            handleAppRefreshTask(appRefreshTask)
        }
    }

    static func scheduleBackgroundRefresh() {
        BGTaskScheduler.shared.cancel(taskRequestWithIdentifier: taskIdentifier)

        guard let refreshPreference = savedRefreshPreference(),
              let refreshInterval = refreshPreference.refreshIntervalInSeconds else {
            return
        }

        let request = BGAppRefreshTaskRequest(identifier: taskIdentifier)

        // This is only a hint to iOS. The system decides if and when the task runs
        // based on battery, usage patterns, network availability, and other signals.
        request.earliestBeginDate = Date(timeIntervalSinceNow: refreshInterval)

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Could not schedule background refresh: \(error.localizedDescription)")
        }
    }

    static func handleAppRefreshTask(_ task: BGAppRefreshTask) {
        scheduleBackgroundRefresh()

        let refreshTask = Task {
            let didRefresh = await refreshAlertsInBackground()
            task.setTaskCompleted(success: didRefresh)
        }

        task.expirationHandler = {
            refreshTask.cancel()
        }
    }

    static func refreshAlertsInBackground() async -> Bool {
        guard savedRefreshPreference()?.refreshIntervalInSeconds != nil else {
            return true
        }

        do {
            let alerts = try await TTCAlertsService().fetchAlertsFeed()
            let lastUpdatedDate = Date()

            saveCachedAlerts(alerts)
            saveLastUpdatedDate(lastUpdatedDate)

            await processAlertNotifications(alerts, shouldSendNotifications: notificationsAreEnabled())

            return true
        } catch {
            print("Could not refresh TTC alerts in the background: \(error.localizedDescription)")
            return false
        }
    }

    private static func processAlertNotifications(_ alerts: [TTCAlert], shouldSendNotifications: Bool) async {
        let savedRoutes = ContentView.loadRoutes()

        for route in savedRoutes {
            let matchingAlerts = RouteAlertStatus.matchingAlerts(for: route, in: alerts)
            let newNotifications = RouteAlertNotificationManager.newAlertNotifications(
                for: route,
                matchingAlerts: matchingAlerts
            )

            guard shouldSendNotifications else {
                continue
            }

            for notification in newNotifications {
                await RouteAlertNotificationManager.scheduleRouteAlertNotification(notification)
            }
        }
    }

    private static func saveCachedAlerts(_ alerts: [TTCAlert]) {
        do {
            let encodedAlerts = try JSONEncoder().encode(alerts)
            UserDefaults.standard.set(encodedAlerts, forKey: ContentView.cachedAlertsKey)
        } catch {
            print("Could not save cached alerts from background refresh")
        }
    }

    private static func saveLastUpdatedDate(_ lastUpdatedDate: Date) {
        UserDefaults.standard.set(lastUpdatedDate, forKey: ContentView.lastUpdatedKey)
    }

    private static func savedRefreshPreference() -> RefreshPreference? {
        let savedPreference = UserDefaults.standard.string(forKey: RefreshPreference.storageKey)
            ?? RefreshPreference.manualOnly.rawValue

        return RefreshPreference(rawValue: savedPreference)
    }

    private static func notificationsAreEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }
}
