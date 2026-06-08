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
    let arrivalDate: Date
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
        let (data, response) = try await URLSession.shared.data(from: tripUpdatesFeedURL)

        if let httpResponse = response as? HTTPURLResponse {
            print("TTC trip updates feed status: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        } else {
            print("TTC trip updates feed response was not an HTTP response")
            throw URLError(.badServerResponse)
        }

        print("TTC trip updates feed data size: \(data.count) bytes")
        return try decodedTripUpdates(from: data)
    }

    func decodedTripUpdates(from data: Data) throws -> [TTCLiveStopTimeUpdate] {
        let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
        let updates = liveStopTimeUpdates(from: feed)

        print("Decoded TTC live stop time updates: \(updates.count)")
        return updates
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
        tripsByID: [String: GTFSTrip],
        routesByID: [String: SuggestedRoute],
        now: Date = Date(),
        limit: Int = 10
    ) -> [StopArrival] {
        liveUpdates
            .filter { update in
                update.stopID == stopID && update.arrivalDate >= now
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

    private func liveStopTimeUpdate(
        from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
        tripID: String,
        routeID: String?
    ) -> TTCLiveStopTimeUpdate? {
        let stopID = stopTimeUpdate.stopID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !stopID.isEmpty,
              let eventTime = eventTime(from: stopTimeUpdate) else {
            return nil
        }

        return TTCLiveStopTimeUpdate(
            tripID: tripID,
            routeID: routeID,
            stopID: stopID,
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
              let route = routesByID[routeID] else {
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

    private static func displayTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
