//
//  RouteMatcher.swift
//  ttc-route-alerts
//

import Foundation

struct RouteMatcher {
    static func matches(_ alert: String, route: TTCAlertRoute) -> Bool {
        let lowercaseAlert = alert.lowercased()
        let alertWords = words(in: lowercaseAlert)

        // First, match the saved route number as its own word so 34 does not match 134 or 934.
        if let routeNumber = routeNumber(for: route), alertWords.contains(routeNumber) {
            return true
        }

        // Next, support route-type phrases that TTC alert text commonly uses.
        if let routeNumber = routeNumber(for: route), let routeType = route.routeType {
            if routeType == .subway, lowercaseAlert.contains("line \(routeNumber)") {
                return true
            }

            if routeType != .subway, lowercaseAlert.contains("route \(routeNumber)") {
                return true
            }
        }

        // Subway Line 1 is often described by either its number or its common line name.
        if isSubwayLineOne(route) {
            let subwayLineOneNames = ["line 1", "yonge-university", "yonge university"]

            if subwayLineOneNames.contains(where: { lowercaseAlert.contains($0) }) {
                return true
            }
        }

        // Nicknames are helpful, but they are a fallback because many route names overlap.
        if let nickname = route.nickname?.lowercased(), !nickname.isEmpty {
            return lowercaseAlert.contains(nickname)
        }

        return false
    }

    static func routeNumber(for route: TTCAlertRoute) -> String? {
        if let routeNumber = route.routeNumber?.lowercased(), !routeNumber.isEmpty {
            return firstNumber(in: routeNumber) ?? routeNumber
        }

        return firstNumber(in: route.name.lowercased())
    }

    private static func isSubwayLineOne(_ route: TTCAlertRoute) -> Bool {
        let routeNumber = routeNumber(for: route)
        let routeName = route.name.lowercased()
        let routeNickname = route.nickname?.lowercased()

        return routeNumber == "1"
            && (route.routeType == .subway
                || routeName.contains("line 1")
                || routeNickname == "yonge-university"
                || routeNickname == "yonge university")
    }

    private static func firstNumber(in text: String) -> String? {
        text
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty }
    }

    private static func words(in text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
