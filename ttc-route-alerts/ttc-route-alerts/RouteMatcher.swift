//
//  RouteMatcher.swift
//  ttc-route-alerts
//

import Foundation

struct RouteMatcher {
    static func matches(_ alert: TTCAlert, route: TTCAlertRoute) -> Bool {
        if let savedRouteID = route.routeID?.lowercased(),
           !savedRouteID.isEmpty,
           alert.routeIDs.contains(where: { $0.lowercased() == savedRouteID }) {
            return true
        }

        return matchesText(alert.text, route: route)
    }

    private static func matchesText(_ alertText: String, route: TTCAlertRoute) -> Bool {
        let lowercaseAlert = alertText.lowercased()
        let alertWords = words(in: lowercaseAlert)
        let savedRouteNumber = routeNumber(for: route)

        // 1. Route number matching is the first text fallback.
        // The number must be a full token so route 39 does not match 939.
        if let savedRouteNumber, alertWords.contains(savedRouteNumber) {
            return true
        }

        // 2. Some TTC text uses phrases like "Line 1" or "Route 939".
        // These still depend on the same saved route number.
        if let savedRouteNumber, let routeType = route.routeType {
            if routeType == .subway, containsFullTokenPhrase(["line", savedRouteNumber], in: alertWords) {
                return true
            }

            if routeType != .subway, containsFullTokenPhrase(["route", savedRouteNumber], in: alertWords) {
                return true
            }
        }

        // 3. Nicknames are only a fallback after route number matching fails.
        // This helps catch names like "Finch Express" without letting names outrank numbers.
        if let nickname = route.nickname?.lowercased(), !nickname.isEmpty {
            return lowercaseAlert.contains(nickname)
        }

        return false
    }

    static func routeNumber(for route: TTCAlertRoute) -> String? {
        if let routeNumber = route.routeNumber?.lowercased(), !routeNumber.isEmpty {
            return firstNumber(in: routeNumber)
        }

        return firstNumber(in: route.name.lowercased())
    }

    private static func firstNumber(in text: String) -> String? {
        text
            .components(separatedBy: CharacterSet.decimalDigits.inverted)
            .first { !$0.isEmpty }
    }

    private static func containsFullTokenPhrase(_ phraseWords: [String], in alertWords: [String]) -> Bool {
        guard !phraseWords.isEmpty, alertWords.count >= phraseWords.count else {
            return false
        }

        for startIndex in 0...(alertWords.count - phraseWords.count) {
            let endIndex = startIndex + phraseWords.count

            if Array(alertWords[startIndex..<endIndex]) == phraseWords {
                return true
            }
        }

        return false
    }

    private static func words(in text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}
