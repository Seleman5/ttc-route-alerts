//
//  TTCStaticScheduleStoreTests.swift
//  ttc-route-alertsTests
//

import XCTest
@testable import ttc_route_alerts

final class TTCStaticScheduleStoreTests: XCTestCase {
    func testParseStopTimesReadsRequiredFields() {
        let stopTimesText = """
        trip_id,arrival_time,departure_time,stop_id,stop_sequence
        trip-a,08:15:00,08:15:30,stop-1,1
        trip-b,25:05:00,25:05:30,stop-1,2
        """

        let stopTimes = TTCStaticScheduleStore.parseStopTimes(from: stopTimesText)

        XCTAssertEqual(stopTimes.count, 2)
        XCTAssertEqual(stopTimes[0].tripID, "trip-a")
        XCTAssertEqual(stopTimes[0].arrivalTime, "08:15:00")
        XCTAssertEqual(stopTimes[0].stopID, "stop-1")
        XCTAssertEqual(stopTimes[0].arrivalSeconds, 29_700)
        XCTAssertEqual(stopTimes[1].arrivalSeconds, 90_300)
    }

    func testParseTripsReadsHeadsignWhenAvailable() {
        let tripsText = """
        route_id,service_id,trip_id,trip_headsign
        route-501,weekday,trip-a,"Long Branch, Westbound"
        route-504,weekday,trip-b,
        """

        let trips = TTCStaticScheduleStore.parseTrips(from: tripsText)

        XCTAssertEqual(trips.count, 2)
        XCTAssertEqual(trips[0], GTFSTrip(tripID: "trip-a", routeID: "route-501", headsign: "Long Branch, Westbound"))
        XCTAssertEqual(trips[1], GTFSTrip(tripID: "trip-b", routeID: "route-504", headsign: nil))
    }

    func testUpcomingArrivalsFiltersPastTimesSortsAndLimitsResults() {
        let stopTimes = [
            GTFSStopTime(tripID: "past", arrivalTime: "08:00:00", stopID: "stop-1", arrivalSeconds: 28_800),
            GTFSStopTime(tripID: "second", arrivalTime: "08:20:00", stopID: "stop-1", arrivalSeconds: 30_000),
            GTFSStopTime(tripID: "first", arrivalTime: "08:10:00", stopID: "stop-1", arrivalSeconds: 29_400),
            GTFSStopTime(tripID: "other-stop", arrivalTime: "08:05:00", stopID: "stop-2", arrivalSeconds: 29_100)
        ]
        let trips = [
            GTFSTrip(tripID: "past", routeID: "route-501", headsign: "Past"),
            GTFSTrip(tripID: "first", routeID: "route-501", headsign: "First"),
            GTFSTrip(tripID: "second", routeID: "route-504", headsign: "Second"),
            GTFSTrip(tripID: "other-stop", routeID: "route-501", headsign: "Other")
        ]
        let routes = [
            SuggestedRoute(routeID: "route-501", routeType: .streetcar, routeNumber: "501", nickname: "Queen"),
            SuggestedRoute(routeID: "route-504", routeType: .streetcar, routeNumber: "504", nickname: "King")
        ]
        let schedule = TTCStaticScheduleStore.scheduleData(stopTimes: stopTimes, trips: trips, routes: routes)

        let arrivals = TTCStaticScheduleStore.upcomingArrivals(
            for: "stop-1",
            in: schedule,
            currentSeconds: 29_000,
            limit: 1
        )

        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(arrivals[0].routeNumber, "501")
        XCTAssertEqual(arrivals[0].routeName, "Queen")
        XCTAssertEqual(arrivals[0].headsign, "First")
        XCTAssertEqual(arrivals[0].arrivalTime, "08:10:00")
        XCTAssertEqual(arrivals[0].source, .scheduled)
    }

    func testSecondsSinceMidnightRejectsInvalidTimes() {
        XCTAssertNil(TTCStaticScheduleStore.secondsSinceMidnight(in: "08:75:00"))
        XCTAssertNil(TTCStaticScheduleStore.secondsSinceMidnight(in: "not-a-time"))
    }

    func testPreferredArrivalsUsesLiveRowsWithoutMixingScheduledRows() {
        let liveArrival = stopArrival(id: "live", source: .live)
        let scheduledArrival = stopArrival(id: "scheduled", source: .scheduled)

        let preferredArrivals = StopArrivalSelection.preferredArrivals(
            liveArrivals: [liveArrival],
            scheduledArrivals: [scheduledArrival]
        )

        XCTAssertEqual(preferredArrivals, [liveArrival])
    }

    func testPreferredArrivalsFallsBackToScheduledWhenLiveIsEmpty() {
        let scheduledArrival = stopArrival(id: "scheduled", source: .scheduled)

        let preferredArrivals = StopArrivalSelection.preferredArrivals(
            liveArrivals: [],
            scheduledArrivals: [scheduledArrival]
        )

        XCTAssertEqual(preferredArrivals, [scheduledArrival])
    }

    private func stopArrival(id: String, source: StopArrivalSource) -> StopArrival {
        StopArrival(
            id: id,
            routeNumber: "501",
            routeName: "Queen",
            headsign: "Long Branch",
            arrivalTime: "08:10:00",
            arrivalSeconds: 29_400,
            arrivalDate: source == .live ? Date(timeIntervalSince1970: 1_800_000_200) : nil,
            source: source
        )
    }
}
