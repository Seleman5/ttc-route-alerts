//
//  TTCTripUpdatesServiceTests.swift
//  ttc-route-alertsTests
//

import XCTest
@testable import ttc_route_alerts

final class TTCTripUpdatesServiceTests: XCTestCase {
    func testLiveStopTimeUpdatesExtractTripStopRouteAndArrivalTime() {
        let feed = tripUpdatesFeed(
            tripID: "trip-a",
            routeID: "route-501",
            stopID: "stop-1",
            arrivalTime: 1_800_000_000
        )

        let updates = TTCTripUpdatesService().liveStopTimeUpdates(from: feed)

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates[0].tripID, "trip-a")
        XCTAssertEqual(updates[0].routeID, "route-501")
        XCTAssertEqual(updates[0].stopID, "stop-1")
        XCTAssertEqual(updates[0].arrivalDate, Date(timeIntervalSince1970: 1_800_000_000))
    }

    func testLiveStopTimeUpdatesUsesDepartureWhenArrivalIsMissing() {
        var stopTimeUpdate = TransitRealtime_TripUpdate.StopTimeUpdate()
        stopTimeUpdate.stopID = "stop-1"
        var departure = TransitRealtime_TripUpdate.StopTimeEvent()
        departure.time = 1_800_000_200
        stopTimeUpdate.departure = departure

        let feed = tripUpdatesFeed(
            tripID: "trip-a",
            routeID: "route-501",
            stopTimeUpdates: [stopTimeUpdate]
        )

        let updates = TTCTripUpdatesService().liveStopTimeUpdates(from: feed)

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates[0].arrivalDate, Date(timeIntervalSince1970: 1_800_000_200))
    }

    func testLiveStopTimeUpdatesPrefersArrivalWhenArrivalAndDepartureExist() {
        var stopTimeUpdate = TransitRealtime_TripUpdate.StopTimeUpdate()
        stopTimeUpdate.stopID = "stop-1"
        var arrival = TransitRealtime_TripUpdate.StopTimeEvent()
        arrival.time = 1_800_000_100
        var departure = TransitRealtime_TripUpdate.StopTimeEvent()
        departure.time = 1_800_000_200
        stopTimeUpdate.arrival = arrival
        stopTimeUpdate.departure = departure

        let feed = tripUpdatesFeed(
            tripID: "trip-a",
            routeID: "route-501",
            stopTimeUpdates: [stopTimeUpdate]
        )

        let updates = TTCTripUpdatesService().liveStopTimeUpdates(from: feed)

        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(updates[0].arrivalDate, Date(timeIntervalSince1970: 1_800_000_100))
    }

    func testStopArrivalsDeduplicatesSameTripStopRouteAndArrivalTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let duplicateUpdate = TTCLiveStopTimeUpdate(
            tripID: "trip-a",
            routeID: "route-501",
            stopID: "stop-1",
            arrivalDate: Date(timeIntervalSince1970: 1_800_000_300)
        )
        let tripsByID = [
            "trip-a": GTFSTrip(tripID: "trip-a", routeID: "route-501", headsign: "Long Branch")
        ]
        let routesByID = [
            "route-501": SuggestedRoute(routeID: "route-501", routeType: .streetcar, routeNumber: "501", nickname: "Queen")
        ]

        let arrivals = TTCTripUpdatesService.stopArrivals(
            from: [duplicateUpdate, duplicateUpdate],
            stopID: "stop-1",
            tripsByID: tripsByID,
            routesByID: routesByID,
            now: now
        )

        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(arrivals[0].id, "live-trip-a-stop-1-route-501-1800000300")
    }

    func testMatchingLiveUpdatesMatchesStopIDSuffixToPlainStopID() {
        let updates = [
            TTCLiveStopTimeUpdate(
                tripID: "trip-a",
                routeID: "route-501",
                stopID: "1234_1",
                arrivalDate: Date(timeIntervalSince1970: 1_800_000_300)
            ),
            TTCLiveStopTimeUpdate(
                tripID: "trip-b",
                routeID: "route-501",
                stopID: "5678",
                arrivalDate: Date(timeIntervalSince1970: 1_800_000_400)
            )
        ]

        let matchingUpdates = TTCTripUpdatesService.matchingLiveUpdates(
            from: updates,
            stopID: "1234"
        )

        XCTAssertEqual(matchingUpdates.map(\.tripID), ["trip-a"])
    }

    func testStopArrivalsMapsBranchRouteIDToBaseRoute() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let updates = [
            TTCLiveStopTimeUpdate(
                tripID: "trip-a",
                routeID: "100A",
                stopID: "stop-1",
                arrivalDate: Date(timeIntervalSince1970: 1_800_000_300)
            )
        ]
        let tripsByID = [
            "trip-a": GTFSTrip(tripID: "trip-a", routeID: "100", headsign: "100A Flemingdon Park")
        ]
        let routesByID = [
            "100": SuggestedRoute(routeID: "100", routeType: .bus, routeNumber: "100", nickname: "Flemingdon Park")
        ]

        let arrivals = TTCTripUpdatesService.stopArrivals(
            from: updates,
            stopID: "stop-1",
            tripsByID: tripsByID,
            routesByID: routesByID,
            now: now
        )

        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(arrivals[0].routeNumber, "100")
        XCTAssertEqual(arrivals[0].routeName, "Flemingdon Park")
    }

    func testStopArrivalsFiltersPastRowsSortsAndLabelsLive() {
        let now = Date(timeIntervalSince1970: 1_800_000_100)
        let updates = [
            TTCLiveStopTimeUpdate(
                tripID: "past",
                routeID: "route-501",
                stopID: "stop-1",
                arrivalDate: Date(timeIntervalSince1970: 1_800_000_000)
            ),
            TTCLiveStopTimeUpdate(
                tripID: "second",
                routeID: "route-504",
                stopID: "stop-1",
                arrivalDate: Date(timeIntervalSince1970: 1_800_000_300)
            ),
            TTCLiveStopTimeUpdate(
                tripID: "first",
                routeID: "route-501",
                stopID: "stop-1",
                arrivalDate: Date(timeIntervalSince1970: 1_800_000_200)
            ),
            TTCLiveStopTimeUpdate(
                tripID: "other-stop",
                routeID: "route-501",
                stopID: "stop-2",
                arrivalDate: Date(timeIntervalSince1970: 1_800_000_150)
            )
        ]
        let tripsByID = [
            "first": GTFSTrip(tripID: "first", routeID: "route-501", headsign: "First headsign"),
            "second": GTFSTrip(tripID: "second", routeID: "route-504", headsign: "Second headsign")
        ]
        let routesByID = [
            "route-501": SuggestedRoute(routeID: "route-501", routeType: .streetcar, routeNumber: "501", nickname: "Queen"),
            "route-504": SuggestedRoute(routeID: "route-504", routeType: .streetcar, routeNumber: "504", nickname: "King")
        ]

        let arrivals = TTCTripUpdatesService.stopArrivals(
            from: updates,
            stopID: "stop-1",
            tripsByID: tripsByID,
            routesByID: routesByID,
            now: now,
            limit: 1
        )

        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(arrivals[0].routeNumber, "501")
        XCTAssertEqual(arrivals[0].routeName, "Queen")
        XCTAssertEqual(arrivals[0].headsign, "First headsign")
        XCTAssertEqual(arrivals[0].source, .live)
        XCTAssertEqual(arrivals[0].arrivalDate, Date(timeIntervalSince1970: 1_800_000_200))
    }

    private func tripUpdatesFeed(
        tripID: String,
        routeID: String,
        stopID: String,
        arrivalTime: Int64
    ) -> TransitRealtime_FeedMessage {
        var stopTimeUpdate = TransitRealtime_TripUpdate.StopTimeUpdate()
        stopTimeUpdate.stopID = stopID
        var arrival = TransitRealtime_TripUpdate.StopTimeEvent()
        arrival.time = arrivalTime
        stopTimeUpdate.arrival = arrival

        return tripUpdatesFeed(
            tripID: tripID,
            routeID: routeID,
            stopTimeUpdates: [stopTimeUpdate]
        )
    }

    private func tripUpdatesFeed(
        tripID: String,
        routeID: String,
        stopTimeUpdates: [TransitRealtime_TripUpdate.StopTimeUpdate]
    ) -> TransitRealtime_FeedMessage {
        var tripDescriptor = TransitRealtime_TripDescriptor()
        tripDescriptor.tripID = tripID
        tripDescriptor.routeID = routeID

        var tripUpdate = TransitRealtime_TripUpdate()
        tripUpdate.trip = tripDescriptor
        tripUpdate.stopTimeUpdate = stopTimeUpdates

        var entity = TransitRealtime_FeedEntity()
        entity.id = "entity-1"
        entity.tripUpdate = tripUpdate

        var header = TransitRealtime_FeedHeader()
        header.gtfsRealtimeVersion = "2.0"

        var feed = TransitRealtime_FeedMessage()
        feed.header = header
        feed.entity = [entity]

        return feed
    }
}
