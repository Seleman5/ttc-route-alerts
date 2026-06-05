//
//  RouteAlertStatus.swift
//  ttc-route-alerts
//

import Foundation

struct RouteAlertStatus {
    static func matchingAlerts(for route: TTCAlertRoute, in alerts: [TTCAlert]) -> [TTCAlert] {
        alerts.filter { alert in
            RouteMatcher.matches(alert, route: route)
        }
    }

    static func matchingAlerts(
        for route: TTCAlertRoute,
        cachedAlerts: [TTCAlert]?,
        allAlerts: [TTCAlert]
    ) -> [TTCAlert] {
        guard let cachedAlerts else {
            return matchingAlerts(for: route, in: allAlerts)
        }

        let routeOnlyCachedAlerts = matchingAlerts(for: route, in: cachedAlerts)

        if routeOnlyCachedAlerts.count == cachedAlerts.count {
            return routeOnlyCachedAlerts
        }

        return matchingAlerts(for: route, in: allAlerts)
    }

    static func severity(for route: TTCAlertRoute, in alerts: [TTCAlert]) -> AlertSeverity {
        let matchingAlerts = matchingAlerts(for: route, in: alerts)
        return AlertSeverity.strongestSeverity(in: matchingAlerts.map(\.text))
    }
}
