//
//  RouteMatcher.swift
//  ttc-route-alerts
//

import Foundation

struct RouteMatcher {
    static func matches(_ alert: TTCAlert, route: TTCAlertRoute) -> Bool {
        if let savedRouteID = route.routeID?.trimmingCharacters(in: .whitespacesAndNewlines),
           !savedRouteID.isEmpty {
            if alert.routeIDs.contains(where: { routeIDsMatch(savedRouteID, $0) }) {
                if routeIDMatchIsSafeForRoute(alertText: alert.text, route: route) {
                    return true
                }
            }
        }

        return matchesText(alert.text, route: route)
    }

    private static func routeIDMatchIsSafeForRoute(alertText: String, route: TTCAlertRoute) -> Bool {
        let routeType = route.routeType ?? .bus
        let lowercaseAlert = alertText.lowercased()
        let alertWords = words(in: lowercaseAlert)
        let savedRouteNumber = routeNumber(for: route)

        if routeType == .subway {
            return subwayRouteIDMatchIsSafe(
                lowercaseAlert: lowercaseAlert,
                alertWords: alertWords,
                route: route,
                savedRouteNumber: savedRouteNumber
            )
        }

        guard routeType == .bus || routeType == .streetcar else {
            return true
        }

        if matchesSurfaceRouteText(
            alertWords: alertWords,
            savedRouteNumber: savedRouteNumber,
            routeType: routeType
        ) {
            return true
        }

        if !explicitlyMentionedLineNumbers(in: alertWords).isEmpty {
            return false
        }

        if containsStationOnlyAlertWords(alertWords) {
            return false
        }

        return true
    }

    private static func matchesText(_ alertText: String, route: TTCAlertRoute) -> Bool {
        let lowercaseAlert = alertText.lowercased()
        let alertWords = words(in: lowercaseAlert)
        let savedRouteNumber = routeNumber(for: route)
        let routeType = route.routeType ?? .bus

        switch routeType {
        case .bus, .streetcar:
            return matchesSurfaceRouteText(
                alertWords: alertWords,
                savedRouteNumber: savedRouteNumber,
                routeType: routeType
            )
        case .subway:
            return matchesSubwayText(
                lowercaseAlert: lowercaseAlert,
                alertWords: alertWords,
                route: route,
                savedRouteNumber: savedRouteNumber
            )
        }
    }

    private static func matchesSurfaceRouteText(
        alertWords: [String],
        savedRouteNumber: String?,
        routeType: RouteType
    ) -> Bool {
        guard let savedRouteNumber else {
            return false
        }

        if explicitlyMentionedLineNumbers(in: alertWords).contains(where: { $0 != savedRouteNumber }) {
            return false
        }

        if alertWords.first == savedRouteNumber {
            return true
        }

        if explicitlyMentionedSurfaceRouteNumbers(in: alertWords, routeType: routeType).contains(savedRouteNumber) {
            return true
        }

        return false
    }

    private static func matchesSubwayText(
        lowercaseAlert: String,
        alertWords: [String],
        route: TTCAlertRoute,
        savedRouteNumber: String?
    ) -> Bool {
        if subwayTextExplicitlyMatchesRoute(
            lowercaseAlert: lowercaseAlert,
            alertWords: alertWords,
            route: route,
            savedRouteNumber: savedRouteNumber
        ) {
            return true
        }

        if containsStationOnlyAlertWords(alertWords) {
            return false
        }

        return false
    }

    private static func subwayRouteIDMatchIsSafe(
        lowercaseAlert: String,
        alertWords: [String],
        route: TTCAlertRoute,
        savedRouteNumber: String?
    ) -> Bool {
        if subwayTextExplicitlyMatchesRoute(
            lowercaseAlert: lowercaseAlert,
            alertWords: alertWords,
            route: route,
            savedRouteNumber: savedRouteNumber
        ) {
            return true
        }

        if !explicitlyMentionedLineNumbers(in: alertWords).isEmpty {
            return false
        }

        // Line 2 has been prone to broad station alert matches from TTC metadata.
        // Until we have a station-to-line map, only explicit Line 2/Bloor-Danforth
        // text should be accepted for this subway line.
        if savedRouteNumber == "2" {
            return false
        }

        if containsStationOnlyAlertWords(alertWords) {
            return false
        }

        return true
    }

    private static func subwayTextExplicitlyMatchesRoute(
        lowercaseAlert: String,
        alertWords: [String],
        route: TTCAlertRoute,
        savedRouteNumber: String?
    ) -> Bool {
        if let savedRouteNumber, containsFullTokenPhrase(["line", savedRouteNumber], in: alertWords) {
            return true
        }

        if let nickname = route.nickname?.lowercased(), !nickname.isEmpty {
            if lowercaseAlert.contains(nickname) {
                return true
            }

            let nicknameWords = words(in: nickname)

            if containsFullTokenPhrase(nicknameWords, in: alertWords) {
                return true
            }
        }

        return false
    }

    private static func explicitlyMentionedLineNumbers(in alertWords: [String]) -> [String] {
        routeNumbersAfterLabels(["line"], in: alertWords)
    }

    private static func containsStationOnlyAlertWords(_ alertWords: [String]) -> Bool {
        alertWords.contains("station")
            || alertWords.contains("elevator")
            || alertWords.contains("escalator")
    }

    private static func explicitlyMentionedSurfaceRouteNumbers(
        in alertWords: [String],
        routeType: RouteType
    ) -> [String] {
        let routeTypeLabels: [String]

        if routeType == .bus {
            routeTypeLabels = ["bus", "buses"]
        } else {
            routeTypeLabels = ["streetcar", "streetcars"]
        }

        return routeNumbersAfterLabels(["route", "routes"] + routeTypeLabels, in: alertWords)
    }

    private static func routeNumbersAfterLabels(_ routeLabelWords: [String], in alertWords: [String]) -> [String] {
        let connectorWords = ["and", "or", "to", "through", "between"]
        var routeNumbers: [String] = []

        for index in alertWords.indices {
            guard routeLabelWords.contains(alertWords[index]) else {
                continue
            }

            var nextIndex = alertWords.index(after: index)

            while nextIndex < alertWords.endIndex {
                let word = alertWords[nextIndex]

                if let routeNumber = firstNumber(in: word) {
                    routeNumbers.append(routeNumber)
                    nextIndex = alertWords.index(after: nextIndex)
                    continue
                }

                if connectorWords.contains(word) {
                    nextIndex = alertWords.index(after: nextIndex)
                    continue
                }

                break
            }
        }

        return routeNumbers
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

    private static func routeIDsMatch(_ savedRouteID: String, _ alertRouteID: String) -> Bool {
        let savedID = savedRouteID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let alertID = alertRouteID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if savedID == alertID {
            return true
        }

        guard let savedRouteCode = leadingRouteCode(in: savedID),
              let alertRouteCode = leadingRouteCode(in: alertID) else {
            return false
        }

        return routeCodesMatch(savedRouteCode, alertRouteCode)
    }

    private static func routeCodesMatch(_ savedRouteCode: String, _ alertRouteCode: String) -> Bool {
        guard let savedParts = routeCodeParts(savedRouteCode),
              let alertParts = routeCodeParts(alertRouteCode),
              savedParts.number == alertParts.number else {
            return false
        }

        if savedParts.suffix == alertParts.suffix {
            return true
        }

        // TTC realtime records can use branch-style ids such as 131A.
        // Only accept a single-letter branch on the same leading route number.
        return savedParts.suffix.isEmpty
            && alertParts.suffix.count == 1
            && alertParts.suffix.allSatisfy(\.isLetter)
    }

    private static func routeCodeParts(_ routeCode: String) -> (number: String, suffix: String)? {
        let number = routeCode.prefix { $0.isNumber }
        let suffix = routeCode.dropFirst(number.count)

        guard !number.isEmpty,
              suffix.allSatisfy(\.isLetter) else {
            return nil
        }

        return (String(number), String(suffix))
    }

    private static func leadingRouteCode(in routeID: String) -> String? {
        let routeCode = routeID.prefix { $0.isLetter || $0.isNumber }

        guard !routeCode.isEmpty else {
            return nil
        }

        return String(routeCode)
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
