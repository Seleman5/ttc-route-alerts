//
//  ttc_route_alertsApp.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-19.
//

import SwiftUI

@main
struct ttc_route_alertsApp: App {
    init() {
        RouteAlertNotificationManager.configureForegroundNotifications()
        BackgroundAlertRefreshManager.registerBackgroundRefresh()
        BackgroundAlertRefreshManager.scheduleBackgroundRefresh()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
