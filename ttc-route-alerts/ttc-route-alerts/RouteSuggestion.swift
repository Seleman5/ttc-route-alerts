//
//  RouteSuggestion.swift
//  ttc-route-alerts
//

import Foundation

struct SuggestedRoute: Identifiable {
    let routeID: String?
    let routeType: RouteType
    let routeNumber: String
    let nickname: String

    var id: String {
        routeID ?? "\(routeType.rawValue)-\(routeNumber)"
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
    static let suggestedRoutes = loadBundledRoutes() ?? fallbackSuggestedRoutes

    static func isSuggestionNickname(_ nickname: String) -> Bool {
        suggestedRoutes.contains { suggestion in
            suggestion.nickname.lowercased() == nickname.lowercased()
        }
    }

    static func matchingSuggestion(for input: String, selectedRouteType: RouteType) -> SuggestedRoute? {
        let cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedInput = normalizedRouteInput(cleanedInput)

        guard let routeNumber = firstNumericWord(in: normalizedInput) ?? firstNumericWord(in: cleanedInput) else {
            return nil
        }

        let matchingRoutes = suggestedRoutes.filter { suggestion in
            suggestion.routeNumber == routeNumber
        }

        if let typedRouteType = routeType(in: cleanedInput),
           let typedMatch = matchingRoutes.first(where: { $0.routeType == typedRouteType }) {
            return typedMatch
        }

        if let selectedTypeMatch = matchingRoutes.first(where: { suggestion in
            suggestion.routeType == selectedRouteType
        }) {
            return selectedTypeMatch
        }

        return matchingRoutes.first
    }

    static func normalizedRouteInput(_ input: String) -> String {
        var cleanedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        var didRemovePrefix = true

        // Remove route type words users may type before the route number.
        while didRemovePrefix {
            didRemovePrefix = false
            let lowercaseInput = cleanedInput.lowercased()

            for prefix in routeInputPrefixes {
                if lowercaseInput == prefix {
                    return ""
                }

                if lowercaseInput.hasPrefix("\(prefix) ") {
                    cleanedInput = String(cleanedInput.dropFirst(prefix.count))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    didRemovePrefix = true
                    break
                }
            }
        }

        return cleanedInput
    }

    private static let routeInputPrefixes = [
        "bus",
        "subway",
        "line",
        "streetcar"
    ]

    private static func routeType(in input: String) -> RouteType? {
        let words = input
            .lowercased()
            .split { !$0.isLetter }
            .map(String.init)

        if words.contains("bus") {
            return .bus
        }

        if words.contains("streetcar") {
            return .streetcar
        }

        if words.contains("subway") || words.contains("line") {
            return .subway
        }

        return nil
    }

    private static func firstNumericWord(in text: String) -> String? {
        text
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .first { word in
                word.allSatisfy { character in
                    character.isNumber
                }
            }
    }

    private static func loadBundledRoutes() -> [SuggestedRoute]? {
        guard let routesFileURL = Bundle.main.url(forResource: "routes", withExtension: "txt") else {
            return nil
        }

        do {
            let routesText = try String(contentsOf: routesFileURL, encoding: .utf8)
            let parsedRoutes = parseGTFSSuggestions(from: routesText)

            if parsedRoutes.isEmpty {
                return nil
            }

            return parsedRoutes
        } catch {
            return nil
        }
    }

    static func parseGTFSSuggestions(from routesText: String) -> [SuggestedRoute] {
        let lines = routesText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let headerLine = lines.first else {
            return []
        }

        let headers = csvFields(in: headerLine).map { csvField in
            csvField.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let routeIDIndex = headers.firstIndex(of: "route_id"),
              let routeShortNameIndex = headers.firstIndex(of: "route_short_name"),
              let routeLongNameIndex = headers.firstIndex(of: "route_long_name"),
              let routeTypeIndex = headers.firstIndex(of: "route_type") else {
            return []
        }

        var routesByID: [String: SuggestedRoute] = [:]

        for line in lines.dropFirst() {
            let fields = csvFields(in: line)

            guard fields.indices.contains(routeShortNameIndex),
                  fields.indices.contains(routeIDIndex),
                  fields.indices.contains(routeLongNameIndex),
                  fields.indices.contains(routeTypeIndex),
                  let routeTypeNumber = Int(fields[routeTypeIndex].trimmingCharacters(in: .whitespacesAndNewlines)),
                  let routeType = routeType(fromGTFSRouteType: routeTypeNumber) else {
                continue
            }

            let routeID = fields[routeIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let routeNumber = fields[routeShortNameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let routeName = fields[routeLongNameIndex].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !routeID.isEmpty, !routeNumber.isEmpty else {
                continue
            }

            let nickname = routeName.isEmpty ? routeNumber : routeName.capitalized
            let suggestion = SuggestedRoute(routeID: routeID, routeType: routeType, routeNumber: routeNumber, nickname: nickname)

            routesByID[suggestion.id] = suggestion
        }

        return routesByID.values.sorted { firstRoute, secondRoute in
            if firstRoute.routeType != secondRoute.routeType {
                return routeTypeSortOrder(firstRoute.routeType) < routeTypeSortOrder(secondRoute.routeType)
            }

            let firstNumber = Int(firstRoute.routeNumber)
            let secondNumber = Int(secondRoute.routeNumber)

            if let firstNumber, let secondNumber, firstNumber != secondNumber {
                return firstNumber < secondNumber
            }

            return firstRoute.routeNumber < secondRoute.routeNumber
        }
    }

    private static func csvFields(in line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var isInsideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]

            if character == "\"" {
                let nextIndex = line.index(after: index)

                if isInsideQuotes, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    currentField.append(character)
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == "," && !isInsideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(character)
            }

            index = line.index(after: index)
        }

        fields.append(currentField)
        return fields
    }

    private static func routeType(fromGTFSRouteType routeType: Int) -> RouteType? {
        switch routeType {
        case 0:
            return .streetcar
        case 1:
            return .subway
        case 3:
            return .bus
        default:
            return nil
        }
    }

    private static func routeTypeSortOrder(_ routeType: RouteType) -> Int {
        switch routeType {
        case .subway:
            return 0
        case .streetcar:
            return 1
        case .bus:
            return 2
        }
    }

    // Temporary starter dataset for route autocomplete.
    // This stays as a fallback if bundled GTFS route data is missing or invalid.
    private static let fallbackSuggestedRoutes = [
        SuggestedRoute(routeID: nil, routeType: .subway, routeNumber: "1", nickname: "Yonge-University"),
        SuggestedRoute(routeID: nil, routeType: .subway, routeNumber: "2", nickname: "Bloor-Danforth"),
        SuggestedRoute(routeID: nil, routeType: .subway, routeNumber: "4", nickname: "Sheppard"),
        SuggestedRoute(routeID: nil, routeType: .streetcar, routeNumber: "501", nickname: "Queen"),
        SuggestedRoute(routeID: nil, routeType: .streetcar, routeNumber: "504", nickname: "King"),
        SuggestedRoute(routeID: nil, routeType: .streetcar, routeNumber: "505", nickname: "Dundas"),
        SuggestedRoute(routeID: nil, routeType: .streetcar, routeNumber: "506", nickname: "Carlton"),
        SuggestedRoute(routeID: nil, routeType: .streetcar, routeNumber: "509", nickname: "Harbourfront"),
        SuggestedRoute(routeID: nil, routeType: .streetcar, routeNumber: "510", nickname: "Spadina"),
        SuggestedRoute(routeID: nil, routeType: .streetcar, routeNumber: "511", nickname: "Bathurst"),
        SuggestedRoute(routeID: nil, routeType: .streetcar, routeNumber: "512", nickname: "St Clair"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "7", nickname: "Bathurst"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "11", nickname: "Bayview"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "12", nickname: "Kingston Road"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "19", nickname: "Bay"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "24", nickname: "Victoria Park"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "25", nickname: "Don Mills"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "29", nickname: "Dufferin"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "32", nickname: "Eglinton West"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "34", nickname: "Eglinton East"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "35", nickname: "Jane"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "36", nickname: "Finch West"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "39", nickname: "Finch East"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "41", nickname: "Keele"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "43", nickname: "Kennedy"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "45", nickname: "Kipling"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "47", nickname: "Lansdowne"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "52", nickname: "Lawrence West"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "53", nickname: "Steeles East"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "54", nickname: "Lawrence East"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "60", nickname: "Steeles West"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "63", nickname: "Ossington"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "68", nickname: "Warden"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "72", nickname: "Pape"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "75", nickname: "Sherbourne"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "84", nickname: "Sheppard West"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "85", nickname: "Sheppard East"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "86", nickname: "Scarborough"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "89", nickname: "Weston"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "94", nickname: "Wellesley"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "95", nickname: "York Mills"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "96", nickname: "Wilson"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "97", nickname: "Yonge"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "100", nickname: "Broadview Station to Flemingdon Park"),
        SuggestedRoute(routeID: nil, routeType: .bus, routeNumber: "116", nickname: "Morningside")
    ]
}
