//
//  TTCBusTimePredictionService.swift
//  ttc-route-alerts
//

import Foundation

struct TTCBusTimePrediction: Equatable {
    let routeTag: String
    let routeTitle: String
    let stopTag: String
    let stopTitle: String
    let directionTitle: String?
    let branch: String?
    let vehicle: String?
    let tripTag: String?
    let arrivalDate: Date
    let seconds: Int?
    let minutes: Int?
}

struct TTCBusTimePredictionService {
    private let baseURL = URL(string: "https://webservices.umoiq.com/service/publicXMLFeed")!

    func fetchPredictions(
        for stopIDs: [String],
        routesByID: [String: SuggestedRoute],
        now: Date = Date(),
        limit: Int = 10
    ) async throws -> [StopArrival] {
        let predictions = try await fetchPredictionRows(for: stopIDs)

        return Self.stopArrivals(
            from: predictions,
            routesByID: routesByID,
            now: now,
            limit: limit
        )
    }

    func fetchPredictionRows(
        for stopIDs: [String],
        requestTimeout: TimeInterval = 12
    ) async throws -> [TTCBusTimePrediction] {
        var lastError: Error?

        for stopID in uniqueStopIDs(from: stopIDs) {
            do {
                let predictions = try await fetchPredictionRows(
                    for: stopID,
                    requestTimeout: requestTimeout
                )

                if !predictions.isEmpty {
                    return predictions
                }
            } catch {
                lastError = error
            }
        }

        if let lastError {
            throw lastError
        }

        return []
    }

    func fetchPredictionRows(
        for stopID: String,
        requestTimeout: TimeInterval = 12
    ) async throws -> [TTCBusTimePrediction] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "command", value: "predictions"),
            URLQueryItem(name: "a", value: "ttc"),
            URLQueryItem(name: "stopId", value: stopID)
        ]

        guard let url = components?.url else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = requestTimeout

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try Self.predictions(from: data)
    }

    static func predictions(from data: Data) throws -> [TTCBusTimePrediction] {
        let parserDelegate = TTCBusTimePredictionParser()
        let parser = XMLParser(data: data)
        parser.delegate = parserDelegate

        guard parser.parse() else {
            throw parser.parserError ?? URLError(.cannotParseResponse)
        }

        return parserDelegate.predictions
    }

    static func stopArrivals(
        from predictions: [TTCBusTimePrediction],
        routesByID: [String: SuggestedRoute],
        now: Date = Date(),
        limit: Int = 10
    ) -> [StopArrival] {
        predictions
            .filter { prediction in
                prediction.arrivalDate >= now
            }
            .sorted { firstPrediction, secondPrediction in
                firstPrediction.arrivalDate < secondPrediction.arrivalDate
            }
            .reduce(into: [StopArrival]()) { arrivals, prediction in
                let arrival = stopArrival(from: prediction, routesByID: routesByID)

                if !arrivals.contains(where: { existingArrival in existingArrival.id == arrival.id }) {
                    arrivals.append(arrival)
                }
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func stopArrival(
        from prediction: TTCBusTimePrediction,
        routesByID: [String: SuggestedRoute]
    ) -> StopArrival {
        let route = route(for: prediction.routeTag, routesByID: routesByID)
        let routeNumber = route?.routeNumber ?? prediction.routeTag
        let routeName = route?.nickname ?? routeName(from: prediction.routeTitle, routeTag: prediction.routeTag)

        return StopArrival(
            id: "bustime-\(prediction.routeTag)-\(prediction.stopTag)-\(prediction.tripTag ?? prediction.vehicle ?? "unknown")-\(Int(prediction.arrivalDate.timeIntervalSince1970))",
            routeNumber: routeNumber,
            routeName: routeName,
            headsign: prediction.directionTitle,
            arrivalTime: displayTime(for: prediction.arrivalDate),
            arrivalSeconds: TTCStaticScheduleStore.secondsSinceMidnight(for: prediction.arrivalDate),
            arrivalDate: prediction.arrivalDate,
            source: .live
        )
    }

    private static func route(for routeTag: String, routesByID: [String: SuggestedRoute]) -> SuggestedRoute? {
        if let route = routesByID[routeTag] {
            return route
        }

        return routesByID.values.first { route in
            route.routeID == routeTag || route.routeNumber == routeTag
        }
    }

    private static func routeName(from routeTitle: String, routeTag: String) -> String {
        let prefix = "\(routeTag)-"

        if routeTitle.hasPrefix(prefix) {
            return String(routeTitle.dropFirst(prefix.count))
        }

        return routeTitle.isEmpty ? "TTC route \(routeTag)" : routeTitle
    }

    private static func displayTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func uniqueStopIDs(from stopIDs: [String]) -> [String] {
        var seenStopIDs: Set<String> = []
        var uniqueStopIDs: [String] = []

        for stopID in stopIDs {
            let cleanedStopID = stopID.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !cleanedStopID.isEmpty,
                  seenStopIDs.insert(cleanedStopID).inserted else {
                continue
            }

            uniqueStopIDs.append(cleanedStopID)
        }

        return uniqueStopIDs
    }
}

private final class TTCBusTimePredictionParser: NSObject, XMLParserDelegate {
    var predictions: [TTCBusTimePrediction] = []

    private var currentRouteTag = ""
    private var currentRouteTitle = ""
    private var currentStopTag = ""
    private var currentStopTitle = ""
    private var currentDirectionTitle: String?

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        switch elementName {
        case "predictions":
            currentRouteTag = attributeDict["routeTag"] ?? ""
            currentRouteTitle = attributeDict["routeTitle"] ?? ""
            currentStopTag = attributeDict["stopTag"] ?? ""
            currentStopTitle = attributeDict["stopTitle"] ?? ""
        case "direction":
            currentDirectionTitle = attributeDict["title"]
        case "prediction":
            guard let prediction = prediction(from: attributeDict) else {
                return
            }

            predictions.append(prediction)
        default:
            break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        if elementName == "direction" {
            currentDirectionTitle = nil
        }
    }

    private func prediction(from attributes: [String: String]) -> TTCBusTimePrediction? {
        guard let epochTimeText = attributes["epochTime"],
              let epochTimeMilliseconds = TimeInterval(epochTimeText) else {
            return nil
        }

        return TTCBusTimePrediction(
            routeTag: currentRouteTag,
            routeTitle: currentRouteTitle,
            stopTag: currentStopTag,
            stopTitle: currentStopTitle,
            directionTitle: currentDirectionTitle,
            branch: attributes["branch"],
            vehicle: attributes["vehicle"],
            tripTag: attributes["tripTag"],
            arrivalDate: Date(timeIntervalSince1970: epochTimeMilliseconds / 1000),
            seconds: attributes["seconds"].flatMap(Int.init),
            minutes: attributes["minutes"].flatMap(Int.init)
        )
    }
}
