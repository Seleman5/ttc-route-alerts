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
            return "Checking live arrivals..."
        case .unavailable:
            return "No nearby live arrival"
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
            return "No nearby live arrival"
        case .arrival(let minutes):
            return "Next live arrival in \(minutes) minutes"
        }
    }
}

struct SavedRouteArrivalCacheEntry {
    let state: SavedRouteArrivalState
    let updatedAt: Date
}

struct SavedRouteArrivalService {
    var fetchPredictions: ([String]) async throws -> [TTCBusTimePrediction]
    var fetchRouteIDsServingStop: (String) async -> Result<Set<String>, TTCStaticScheduleError>
    var nearbyStopLimit: Int

    init(
        fetchPredictions: @escaping ([String]) async throws -> [TTCBusTimePrediction] = { stopIDs in
            try await TTCBusTimePredictionService().fetchPredictionRows(for: stopIDs)
        },
        fetchRouteIDsServingStop: @escaping (String) async -> Result<Set<String>, TTCStaticScheduleError> = { stopID in
            await Task.detached {
                TTCStaticScheduleStore.routeIDsServingStop(for: stopID)
            }.value
        },
        nearbyStopLimit: Int = 12
    ) {
        self.fetchPredictions = fetchPredictions
        self.fetchRouteIDsServingStop = fetchRouteIDsServingStop
        self.nearbyStopLimit = nearbyStopLimit
    }

    func nextArrivalState(
        for route: TTCAlertRoute,
        currentLocation: CLLocation,
        stops: [TTCStop],
        now: Date = Date()
    ) async -> SavedRouteArrivalState {
        guard route.supportsSavedRouteLiveArrival else {
            return .unavailable
        }

        let nearbyStops = TTCStopsStore.closestStops(
            to: currentLocation,
            from: stops,
            limit: nearbyStopLimit
        )

        guard !nearbyStops.isEmpty else {
            return .unavailable
        }

        let candidateStops = await stopsServedByRoute(route, nearbyStops: nearbyStops)

        if candidateStops.hasStaticValidation, candidateStops.stops.isEmpty {
            return .unavailable
        }

        let stopsToCheck = candidateStops.hasStaticValidation ? candidateStops.stops : nearbyStops

        for nearbyStop in stopsToCheck {
            guard let nextPrediction = await nextPrediction(
                for: route,
                at: nearbyStop.stop,
                now: now
            ) else {
                continue
            }

            return .arrival(minutes: minutesUntilArrival(nextPrediction.arrivalDate, now: now))
        }

        return .unavailable
    }

    private func stopsServedByRoute(
        _ route: TTCAlertRoute,
        nearbyStops: [NearbyStop]
    ) async -> (stops: [NearbyStop], hasStaticValidation: Bool) {
        var validatedStops: [NearbyStop] = []
        var hasStaticValidation = false

        for nearbyStop in nearbyStops {
            let result = await fetchRouteIDsServingStop(nearbyStop.stop.stopID)

            guard case .success(let routeIDs) = result else {
                continue
            }

            hasStaticValidation = true

            if routeIDs.contains(where: { routeID in Self.routeID(routeID, matches: route) }) {
                validatedStops.append(nearbyStop)
            }
        }

        return (validatedStops, hasStaticValidation)
    }

    private func nextPrediction(
        for route: TTCAlertRoute,
        at stop: TTCStop,
        now: Date
    ) async -> TTCBusTimePrediction? {
        guard let predictions = try? await fetchPredictions(stop.matchingStopIDs) else {
            return nil
        }

        return predictions
            .filter { prediction in
                prediction.arrivalDate >= now && Self.prediction(prediction, matches: route)
            }
            .sorted { firstPrediction, secondPrediction in
                firstPrediction.arrivalDate < secondPrediction.arrivalDate
            }
            .first
    }

    private func minutesUntilArrival(_ arrivalDate: Date, now: Date) -> Int {
        max(0, Int((arrivalDate.timeIntervalSince(now) / 60).rounded()))
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
