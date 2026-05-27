//
//  RouteInputValidator.swift
//  ttc-route-alerts
//

import Foundation

struct RouteInputValidationResult {
    let route: TTCAlertRoute?
    let errorMessage: String?

    var isValid: Bool {
        route != nil
    }
}

enum RouteInputValidator {
    static func validateRoute(
        routeInput: String,
        nicknameInput: String = "",
        selectedRouteType: RouteType,
        id: UUID = UUID(),
        status: String = "Checking status..."
    ) -> RouteInputValidationResult {
        let cleanedRouteInput = routeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedNickname = nicknameInput.trimmingCharacters(in: .whitespacesAndNewlines)

        // Always calculate a fresh suggestion from the current input before saving.
        guard let matchingSuggestion = RouteSuggestion.matchingSuggestion(
            for: cleanedRouteInput,
            selectedRouteType: selectedRouteType
        ) else {
            return RouteInputValidationResult(
                route: nil,
                errorMessage: validationMessage(for: selectedRouteType)
            )
        }

        let nickname: String

        if cleanedNickname.isEmpty || RouteSuggestion.isSuggestionNickname(cleanedNickname) {
            nickname = matchingSuggestion.nickname
        } else {
            nickname = cleanedNickname
        }

        let route = TTCAlertRoute(
            id: id,
            name: matchingSuggestion.routeNumber,
            status: status,
            routeID: matchingSuggestion.routeID,
            routeType: matchingSuggestion.routeType,
            routeNumber: matchingSuggestion.routeNumber,
            nickname: nickname
        )

        return RouteInputValidationResult(route: route, errorMessage: nil)
    }

    static func validationMessage(for routeType: RouteType) -> String {
        switch routeType {
        case .subway:
            return "That doesn't look like a valid subway line."
        case .streetcar:
            return "That doesn't look like a valid streetcar route."
        case .bus:
            return "That doesn't look like a valid bus route."
        }
    }

    static func routeAlreadySaved(
        _ newRoute: TTCAlertRoute,
        in savedRoutes: [TTCAlertRoute],
        excludingRouteID: UUID? = nil
    ) -> Bool {
        savedRoutes.contains { savedRoute in
            if savedRoute.id == excludingRouteID {
                return false
            }

            let sameDisplayName = savedRoute.displayName.lowercased() == newRoute.displayName.lowercased()
            let sameRouteType = savedRoute.routeType == nil || savedRoute.routeType == newRoute.routeType
            let sameRouteNumber = RouteMatcher.routeNumber(for: savedRoute) == RouteMatcher.routeNumber(for: newRoute)

            return sameDisplayName || (sameRouteType && sameRouteNumber)
        }
    }
}
