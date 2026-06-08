//
//  TTCTripUpdatesService.swift
//  ttc-route-alerts
//

import Foundation
import SwiftProtobuf

struct TTCLiveStopTimeUpdate: Equatable {
    let tripID: String
    let routeID: String?
    let stopID: String
    let stopSequence: Int?
    let arrivalDate: Date

    init(
        tripID: String,
        routeID: String?,
        stopID: String,
        stopSequence: Int? = nil,
        arrivalDate: Date
    ) {
        self.tripID = tripID
        self.routeID = routeID
        self.stopID = stopID
        self.stopSequence = stopSequence
        self.arrivalDate = arrivalDate
    }
}

struct TTCTripUpdatesService {
    let tripUpdatesFeedURL = URL(string: "https://bustime.ttc.ca/gtfsrt/trips")!

    func fetchUpcomingArrivals(
        for stopID: String,
        tripsByID: [String: GTFSTrip],
        routesByID: [String: SuggestedRoute],
        now: Date = Date(),
        limit: Int = 10
    ) async throws -> [StopArrival] {
        let liveUpdates = try await fetchTripUpdatesFeed()

        return Self.stopArrivals(
            from: liveUpdates,
            stopID: stopID,
            tripsByID: tripsByID,
            routesByID: routesByID,
            now: now,
            limit: limit
        )
    }

    func fetchTripUpdatesFeed() async throws -> [TTCLiveStopTimeUpdate] {
        var request = URLRequest(url: tripUpdatesFeedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        } else {
            throw URLError(.badServerResponse)
        }

        return try decodedTripUpdates(from: data)
    }

    func decodedTripUpdates(from data: Data) throws -> [TTCLiveStopTimeUpdate] {
        let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
        return liveStopTimeUpdates(from: feed)
    }

    func liveStopTimeUpdates(from feed: TransitRealtime_FeedMessage) -> [TTCLiveStopTimeUpdate] {
        var updates: [TTCLiveStopTimeUpdate] = []

        for entity in feed.entity {
            guard entity.hasTripUpdate else {
                continue
            }

            let tripUpdate = entity.tripUpdate
            let trip = tripUpdate.trip
            let tripID = trip.tripID.trimmingCharacters(in: .whitespacesAndNewlines)
            let routeID = trip.hasRouteID ? trip.routeID.trimmingCharacters(in: .whitespacesAndNewlines) : ""

            guard !tripID.isEmpty else {
                continue
            }

            for stopTimeUpdate in tripUpdate.stopTimeUpdate {
                guard let update = liveStopTimeUpdate(
                    from: stopTimeUpdate,
                    tripID: tripID,
                    routeID: routeID.isEmpty ? nil : routeID
                ) else {
                    continue
                }

                updates.append(update)
            }
        }

        return updates
    }

    static func stopArrivals(
        from liveUpdates: [TTCLiveStopTimeUpdate],
        stopID: String,
        alternateStopIDs: [String] = [],
        stopTimeSequenceKeys: Set<String> = [],
        tripsByID: [String: GTFSTrip],
        routesByID: [String: SuggestedRoute],
        now: Date = Date(),
        limit: Int = 10
    ) -> [StopArrival] {
        matchingLiveUpdates(
            from: liveUpdates,
            stopID: stopID,
            alternateStopIDs: alternateStopIDs,
            stopTimeSequenceKeys: stopTimeSequenceKeys
        )
            .filter { update in
                update.arrivalDate >= now
            }
            .sorted { firstUpdate, secondUpdate in
                firstUpdate.arrivalDate < secondUpdate.arrivalDate
            }
            .reduce(into: [StopArrival]()) { arrivals, update in
                guard let arrival = stopArrival(
                    from: update,
                    tripsByID: tripsByID,
                    routesByID: routesByID
                ) else {
                    return
                }

                if !arrivals.contains(where: { existingArrival in
                    existingArrival.id == arrival.id
                }) {
                    arrivals.append(arrival)
                }
            }
            .prefix(limit)
            .map { $0 }
    }

    static func matchingLiveUpdates(
        from liveUpdates: [TTCLiveStopTimeUpdate],
        stopID: String,
        alternateStopIDs: [String] = [],
        stopTimeSequenceKeys: Set<String> = []
    ) -> [TTCLiveStopTimeUpdate] {
        let stopIDsToMatch = [stopID] + alternateStopIDs

        return liveUpdates.filter { update in
            stopIDsToMatch.contains { candidateStopID in
                stopIDsMatch(update.stopID, candidateStopID)
            } || sequenceKeyMatches(update, stopTimeSequenceKeys: stopTimeSequenceKeys)
        }
    }

    private func liveStopTimeUpdate(
        from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
        tripID: String,
        routeID: String?
    ) -> TTCLiveStopTimeUpdate? {
        let stopID = stopTimeUpdate.stopID.trimmingCharacters(in: .whitespacesAndNewlines)
        let stopSequence = stopTimeUpdate.hasStopSequence ? Int(stopTimeUpdate.stopSequence) : nil

        guard (!stopID.isEmpty || stopSequence != nil),
              let eventTime = eventTime(from: stopTimeUpdate) else {
            return nil
        }

        return TTCLiveStopTimeUpdate(
            tripID: tripID,
            routeID: routeID,
            stopID: stopID,
            stopSequence: stopSequence,
            arrivalDate: Date(timeIntervalSince1970: TimeInterval(eventTime))
        )
    }

    private func eventTime(from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate) -> Int64? {
        if stopTimeUpdate.hasArrival, stopTimeUpdate.arrival.hasTime {
            return stopTimeUpdate.arrival.time
        }

        if stopTimeUpdate.hasDeparture, stopTimeUpdate.departure.hasTime {
            return stopTimeUpdate.departure.time
        }

        return nil
    }

    private static func stopArrival(
        from liveUpdate: TTCLiveStopTimeUpdate,
        tripsByID: [String: GTFSTrip],
        routesByID: [String: SuggestedRoute]
    ) -> StopArrival? {
        let routeID = liveUpdate.routeID ?? tripsByID[liveUpdate.tripID]?.routeID

        guard let routeID,
              let route = route(for: routeID, routesByID: routesByID) else {
            return nil
        }

        let headsign = tripsByID[liveUpdate.tripID]?.headsign

        return StopArrival(
            id: "live-\(liveUpdate.tripID)-\(liveUpdate.stopID)-\(routeID)-\(Int(liveUpdate.arrivalDate.timeIntervalSince1970))",
            routeNumber: route.routeNumber,
            routeName: route.nickname,
            headsign: headsign,
            arrivalTime: displayTime(for: liveUpdate.arrivalDate),
            arrivalSeconds: TTCStaticScheduleStore.secondsSinceMidnight(for: liveUpdate.arrivalDate),
            arrivalDate: liveUpdate.arrivalDate,
            source: .live
        )
    }

    private static func stopIDsMatch(_ firstStopID: String, _ secondStopID: String) -> Bool {
        let first = firstStopID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let second = secondStopID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        if first == second {
            return true
        }

        if normalizedStopID(first) == normalizedStopID(second) {
            return true
        }

        guard let firstLeadingNumber = leadingNumber(in: first),
              let secondLeadingNumber = leadingNumber(in: second) else {
            return false
        }

        return (first == firstLeadingNumber && secondLeadingNumber == first)
            || (second == secondLeadingNumber && firstLeadingNumber == second)
    }

    private static func sequenceKeyMatches(
        _ liveUpdate: TTCLiveStopTimeUpdate,
        stopTimeSequenceKeys: Set<String>
    ) -> Bool {
        guard let stopSequence = liveUpdate.stopSequence,
              !stopTimeSequenceKeys.isEmpty else {
            return false
        }

        return stopTimeSequenceKeys.contains(
            TTCStaticScheduleStore.sequenceKey(
                tripID: liveUpdate.tripID,
                stopSequence: stopSequence
            )
        )
    }

    private static func normalizedStopID(_ stopID: String) -> String {
        stopID
            .filter { character in
                character.isLetter || character.isNumber
            }
            .lowercased()
    }

    private static func route(
        for routeID: String,
        routesByID: [String: SuggestedRoute]
    ) -> SuggestedRoute? {
        if let route = routesByID[routeID] {
            return route
        }

        guard let routeNumber = leadingNumber(in: routeID) else {
            return nil
        }

        return routesByID.values.first { route in
            route.routeID == routeNumber || route.routeNumber == routeNumber
        }
    }

    private static func leadingNumber(in text: String) -> String? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmedText.prefix { character in
            character.isNumber
        }

        guard !digits.isEmpty else {
            return nil
        }

        return String(digits)
    }

    private static func displayTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
