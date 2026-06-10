//
//  SavedRouteArrivalService.swift
//  ttc-route-alerts
//

import CoreLocation
import Foundation

enum SavedRouteArrivalState: Equatable {
    case loading
    case unavailable
    case arrival(minutes: Int)

    var displayText: String {
        switch self {
        case .loading:
            return "Checking arrivals..."
        case .unavailable:
            return "Arrival unavailable"
        case .arrival(let minutes):
            if minutes == 1 {
                return "Next arrival: 1 min"
            }

            return "Next arrival: \(minutes) min"
        }
    }

    var accessibilityText: String {
        switch self {
        case .loading:
            return "Checking live arrivals"
        case .unavailable:
            return "Arrival unavailable"
        case .arrival(let minutes):
            return "Next live arrival in \(minutes) minutes"
        }
    }
}

struct SavedRouteArrivalCacheEntry {
    let state: SavedRouteArrivalState
    let updatedAt: Date
}

struct SavedRouteArrivalDebugInfo: Equatable {
    let selectedStopName: String?
    let selectedStopID: String?
    let selectedStopDistanceInMeters: CLLocationDistance?
    let nearestSearchedStopName: String?
    let nearestSearchedStopID: String?
    let nearestSearchedStopDistanceInMeters: CLLocationDistance?
    let didBusTimeReturnPredictionsForSelectedStop: Bool
}

struct SavedRouteArrivalResult: Equatable {
    let state: SavedRouteArrivalState
    let debugInfo: SavedRouteArrivalDebugInfo
}

struct SavedRouteArrivalService {
    var fetchPredictions: ([String], TimeInterval) async throws -> [TTCBusTimePrediction]
    var nearbyStopLimit: Int
    var maxStopDistanceInMeters: CLLocationDistance?
    var lookupTimeout: TimeInterval

    init(
        fetchPredictions: @escaping ([String], TimeInterval) async throws -> [TTCBusTimePrediction] = { stopIDs, timeout in
            try await TTCBusTimePredictionService().fetchPredictionRows(
                for: stopIDs,
                requestTimeout: timeout
            )
        },
        nearbyStopLimit: Int = 12,
        maxStopDistanceInMeters: CLLocationDistance? = 800,
        lookupTimeout: TimeInterval = 2.5
    ) {
        self.fetchPredictions = fetchPredictions
        self.nearbyStopLimit = nearbyStopLimit
        self.maxStopDistanceInMeters = maxStopDistanceInMeters
        self.lookupTimeout = lookupTimeout
    }

    func nextArrivalStates(
        for routes: [TTCAlertRoute],
        currentLocation: CLLocation,
        stops: [TTCStop],
        now: Date = Date()
    ) async -> [UUID: SavedRouteArrivalState] {
        let results = await nextArrivalResults(
            for: routes,
            currentLocation: currentLocation,
            stops: stops,
            now: now
        )

        return results.mapValues(\.state)
    }

    func nextArrivalResults(
        for routes: [TTCAlertRoute],
        currentLocation: CLLocation,
        stops: [TTCStop],
        now: Date = Date()
    ) async -> [UUID: SavedRouteArrivalResult] {
        let eligibleRoutes = routes.filter { route in
            route.supportsSavedRouteLiveArrival
        }

        guard !eligibleRoutes.isEmpty else {
            return [:]
        }

        let nearbyStops = stopsForSavedRouteArrivalPreview(
            to: currentLocation,
            from: stops
        )

        guard !nearbyStops.isEmpty else {
            return unavailableResults(for: eligibleRoutes, nearestSearchedStop: nil)
        }

        let predictionsByStopID = await livePredictionsByStopID(for: nearbyStops)
        var results: [UUID: SavedRouteArrivalResult] = [:]

        for route in eligibleRoutes {
            results[route.id] = nextArrivalResult(
                for: route,
                nearbyStops: nearbyStops,
                predictionsByStopID: predictionsByStopID,
                now: now
            )
        }

        return results
    }

    private func livePredictionsByStopID(
        for nearbyStops: [NearbyStop]
    ) async -> [String: [TTCBusTimePrediction]] {
        await withTaskGroup(of: (String, [TTCBusTimePrediction]).self) { group in
            for nearbyStop in nearbyStops {
                let stop = nearbyStop.stop
                let stopIDs = stop.matchingStopIDs
                let timeout = lookupTimeout
                let fetchPredictions = fetchPredictions

                group.addTask {
                    let predictions = await Self.predictionsWithTimeout(
                        stopIDs: stopIDs,
                        timeout: timeout,
                        fetchPredictions: fetchPredictions
                    )

                    return (stop.stopID, predictions)
                }
            }

            var predictionsByStopID: [String: [TTCBusTimePrediction]] = [:]

            for await (stopID, predictions) in group {
                predictionsByStopID[stopID] = predictions
            }

            return predictionsByStopID
        }
    }

    private func stopsForSavedRouteArrivalPreview(
        to currentLocation: CLLocation,
        from stops: [TTCStop]
    ) -> [NearbyStop] {
        let closestStops = TTCStopsStore.closestStops(
            to: currentLocation,
            from: stops,
            limit: nearbyStopLimit
        )

        guard let maxStopDistanceInMeters else {
            return closestStops
        }

        return closestStops.filter { nearbyStop in
            nearbyStop.distanceInMeters <= maxStopDistanceInMeters
        }
    }

    private func nextArrivalResult(
        for route: TTCAlertRoute,
        nearbyStops: [NearbyStop],
        predictionsByStopID: [String: [TTCBusTimePrediction]],
        now: Date
    ) -> SavedRouteArrivalResult {
        let nearestSearchedStop = nearbyStops.first

        for nearbyStop in nearbyStops {
            let predictions = predictionsByStopID[nearbyStop.stop.stopID] ?? []
            let matchingPrediction = predictions
                .filter { prediction in
                    prediction.arrivalDate >= now && Self.prediction(prediction, matches: route)
                }
                .sorted { firstPrediction, secondPrediction in
                    firstPrediction.arrivalDate < secondPrediction.arrivalDate
                }
                .first

            if let matchingPrediction {
                return SavedRouteArrivalResult(
                    state: .arrival(minutes: minutesUntilArrival(matchingPrediction.arrivalDate, now: now)),
                    debugInfo: debugInfo(
                        selectedStop: nearbyStop,
                        nearestSearchedStop: nearestSearchedStop,
                        didBusTimeReturnPredictionsForSelectedStop: !predictions.isEmpty
                    )
                )
            }
        }

        return SavedRouteArrivalResult(
            state: .unavailable,
            debugInfo: debugInfo(
                selectedStop: nil,
                nearestSearchedStop: nearestSearchedStop,
                didBusTimeReturnPredictionsForSelectedStop: nearestSearchedStop
                    .map { !(predictionsByStopID[$0.stop.stopID] ?? []).isEmpty } ?? false
            )
        )
    }

    private func unavailableResults(
        for routes: [TTCAlertRoute],
        nearestSearchedStop: NearbyStop?
    ) -> [UUID: SavedRouteArrivalResult] {
        Dictionary(uniqueKeysWithValues: routes.map { route in
            (
                route.id,
                SavedRouteArrivalResult(
                    state: .unavailable,
                    debugInfo: debugInfo(
                        selectedStop: nil,
                        nearestSearchedStop: nearestSearchedStop,
                        didBusTimeReturnPredictionsForSelectedStop: false
                    )
                )
            )
        })
    }

    private func debugInfo(
        selectedStop: NearbyStop?,
        nearestSearchedStop: NearbyStop?,
        didBusTimeReturnPredictionsForSelectedStop: Bool
    ) -> SavedRouteArrivalDebugInfo {
        SavedRouteArrivalDebugInfo(
            selectedStopName: selectedStop?.stop.stopName,
            selectedStopID: selectedStop?.stop.stopID,
            selectedStopDistanceInMeters: selectedStop?.distanceInMeters,
            nearestSearchedStopName: nearestSearchedStop?.stop.stopName,
            nearestSearchedStopID: nearestSearchedStop?.stop.stopID,
            nearestSearchedStopDistanceInMeters: nearestSearchedStop?.distanceInMeters,
            didBusTimeReturnPredictionsForSelectedStop: didBusTimeReturnPredictionsForSelectedStop
        )
    }

    private func minutesUntilArrival(_ arrivalDate: Date, now: Date) -> Int {
        max(0, Int((arrivalDate.timeIntervalSince(now) / 60).rounded()))
    }

    static func predictionsWithTimeout(
        stopIDs: [String],
        timeout: TimeInterval,
        fetchPredictions: @escaping ([String], TimeInterval) async throws -> [TTCBusTimePrediction]
    ) async -> [TTCBusTimePrediction] {
        do {
            return try await withThrowingTaskGroup(of: [TTCBusTimePrediction].self) { group in
                group.addTask {
                    try await fetchPredictions(stopIDs, timeout)
                }

                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                    throw URLError(.timedOut)
                }

                let predictions = try await group.next() ?? []
                group.cancelAll()
                return predictions
            }
        } catch {
            return []
        }
    }

    static func prediction(_ prediction: TTCBusTimePrediction, matches route: TTCAlertRoute) -> Bool {
        let predictionRouteValues = [
            prediction.routeTag,
            prediction.branch
        ]
        .compactMap { $0 }

        return predictionRouteValues.contains { predictionRouteValue in
            routeID(predictionRouteValue, matches: route)
        }
    }

    static func routeID(_ routeID: String, matches route: TTCAlertRoute) -> Bool {
        let savedRouteValues = [
            route.routeID,
            route.routeNumber,
            route.name
        ]
        .compactMap { $0 }

        return savedRouteValues.contains { savedRouteValue in
            normalizedRouteNumber(routeID) == normalizedRouteNumber(savedRouteValue)
        }
    }

    private static func normalizedRouteNumber(_ routeText: String) -> String {
        let trimmedRouteText = routeText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let firstNumber = firstNumericSequence(in: trimmedRouteText) {
            return firstNumber
        }

        return trimmedRouteText.lowercased()
    }

    private static func firstNumericSequence(in text: String) -> String? {
        var digits = ""

        for character in text {
            if character.isNumber {
                digits.append(character)
            } else if !digits.isEmpty {
                return digits
            }
        }

        return digits.isEmpty ? nil : digits
    }
}

private extension TTCAlertRoute {
    var supportsSavedRouteLiveArrival: Bool {
        routeType == .bus || routeType == .streetcar
    }
}
