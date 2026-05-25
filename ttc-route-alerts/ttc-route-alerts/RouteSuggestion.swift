//
//  RouteSuggestion.swift
//  ttc-route-alerts
//

import Foundation

struct SuggestedRoute: Identifiable {
    let routeType: RouteType
    let routeNumber: String
    let nickname: String

    var id: String {
        "\(routeType.rawValue)-\(routeNumber)"
    }

    var displayName: String {
        "\(typeLabel) \(routeNumber) - \(nickname)"
    }

    var typeLabel: String {
        if routeType == .subway {
            return "Subway Line"
        } else {
            return routeType.rawValue
        }
    }

    func matches(_ searchText: String) -> Bool {
        let searchableText = [
            routeType.rawValue,
            typeLabel,
            routeNumber,
            nickname,
            displayName
        ]
        .joined(separator: " ")
        .lowercased()

        return searchText
            .split(separator: " ")
            .allSatisfy { searchableText.contains($0) }
    }
}

enum RouteSuggestion {
    // Temporary starter dataset for route autocomplete.
    // Later, this should be replaced with a full TTC GTFS routes database.
    static let suggestedRoutes = [
        SuggestedRoute(routeType: .subway, routeNumber: "1", nickname: "Yonge-University"),
        SuggestedRoute(routeType: .subway, routeNumber: "2", nickname: "Bloor-Danforth"),
        SuggestedRoute(routeType: .subway, routeNumber: "4", nickname: "Sheppard"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "501", nickname: "Queen"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "504", nickname: "King"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "505", nickname: "Dundas"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "506", nickname: "Carlton"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "509", nickname: "Harbourfront"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "510", nickname: "Spadina"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "511", nickname: "Bathurst"),
        SuggestedRoute(routeType: .streetcar, routeNumber: "512", nickname: "St Clair"),
        SuggestedRoute(routeType: .bus, routeNumber: "7", nickname: "Bathurst"),
        SuggestedRoute(routeType: .bus, routeNumber: "11", nickname: "Bayview"),
        SuggestedRoute(routeType: .bus, routeNumber: "12", nickname: "Kingston Road"),
        SuggestedRoute(routeType: .bus, routeNumber: "19", nickname: "Bay"),
        SuggestedRoute(routeType: .bus, routeNumber: "24", nickname: "Victoria Park"),
        SuggestedRoute(routeType: .bus, routeNumber: "25", nickname: "Don Mills"),
        SuggestedRoute(routeType: .bus, routeNumber: "29", nickname: "Dufferin"),
        SuggestedRoute(routeType: .bus, routeNumber: "32", nickname: "Eglinton West"),
        SuggestedRoute(routeType: .bus, routeNumber: "34", nickname: "Eglinton East"),
        SuggestedRoute(routeType: .bus, routeNumber: "35", nickname: "Jane"),
        SuggestedRoute(routeType: .bus, routeNumber: "36", nickname: "Finch West"),
        SuggestedRoute(routeType: .bus, routeNumber: "39", nickname: "Finch East"),
        SuggestedRoute(routeType: .bus, routeNumber: "41", nickname: "Keele"),
        SuggestedRoute(routeType: .bus, routeNumber: "43", nickname: "Kennedy"),
        SuggestedRoute(routeType: .bus, routeNumber: "45", nickname: "Kipling"),
        SuggestedRoute(routeType: .bus, routeNumber: "47", nickname: "Lansdowne"),
        SuggestedRoute(routeType: .bus, routeNumber: "52", nickname: "Lawrence West"),
        SuggestedRoute(routeType: .bus, routeNumber: "53", nickname: "Steeles East"),
        SuggestedRoute(routeType: .bus, routeNumber: "54", nickname: "Lawrence East"),
        SuggestedRoute(routeType: .bus, routeNumber: "60", nickname: "Steeles West"),
        SuggestedRoute(routeType: .bus, routeNumber: "63", nickname: "Ossington"),
        SuggestedRoute(routeType: .bus, routeNumber: "68", nickname: "Warden"),
        SuggestedRoute(routeType: .bus, routeNumber: "72", nickname: "Pape"),
        SuggestedRoute(routeType: .bus, routeNumber: "75", nickname: "Sherbourne"),
        SuggestedRoute(routeType: .bus, routeNumber: "84", nickname: "Sheppard West"),
        SuggestedRoute(routeType: .bus, routeNumber: "85", nickname: "Sheppard East"),
        SuggestedRoute(routeType: .bus, routeNumber: "86", nickname: "Scarborough"),
        SuggestedRoute(routeType: .bus, routeNumber: "89", nickname: "Weston"),
        SuggestedRoute(routeType: .bus, routeNumber: "94", nickname: "Wellesley"),
        SuggestedRoute(routeType: .bus, routeNumber: "95", nickname: "York Mills"),
        SuggestedRoute(routeType: .bus, routeNumber: "96", nickname: "Wilson"),
        SuggestedRoute(routeType: .bus, routeNumber: "97", nickname: "Yonge"),
        SuggestedRoute(routeType: .bus, routeNumber: "100", nickname: "Flemingdon Park"),
        SuggestedRoute(routeType: .bus, routeNumber: "116", nickname: "Morningside")
    ]
}
