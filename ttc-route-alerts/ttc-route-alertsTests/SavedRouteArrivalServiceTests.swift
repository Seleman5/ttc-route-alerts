//
//  SavedRouteArrivalServiceTests.swift
//  ttc-route-alertsTests
//

import CoreLocation
import XCTest
@testable import ttc_route_alerts

final class SavedRouteArrivalServiceTests: XCTestCase {
    func testSubwayRouteDoesNotFetchSavedRouteArrival() async {
        let route = TTCAlertRoute(
            name: "1",
            status: "No major issues",
            routeType: .subway,
            routeNumber: "1",
            nickname: "Yonge-University"
        )
        var predictionFetchCount = 0
        let service = SavedRouteArrivalService(
            fetchPredictions: { _, _ in
                predictionFetchCount += 1
                return []
            }
        )

        let states = await service.nextArrivalStates(
            for: [route],
            currentLocation: userLocation,
            stops: [stop(id: "stop-1", latitudeOffset: 0.001)]
        )

        XCTAssertTrue(states.isEmpty)
        XCTAssertEqual(predictionFetchCount, 0)
    }

    func testFetchesPredictionsOncePerNearbyStopForMultipleRoutes() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let route100 = busRoute(number: "100")
        let route32 = busRoute(number: "32")
        var fetchedStopIDs: [[String]] = []
        let service = SavedRouteArrivalService(
            fetchPredictions: { stopIDs, _ in
                fetchedStopIDs.append(stopIDs)
                return [
                    self.prediction(routeTag: "100", arrivalDate: Date(timeIntervalSince1970: 1_800_000_360)),
                    self.prediction(routeTag: "32", arrivalDate: Date(timeIntervalSince1970: 1_800_000_540))
                ]
            },
            nearbyStopLimit: 1
        )

        let states = await service.nextArrivalStates(
            for: [route100, route32],
            currentLocation: userLocation,
            stops: [stop(id: "near-stop", stopCode: "near-code", latitudeOffset: 0.001)],
            now: now
        )

        XCTAssertEqual(states[route100.id], .arrival(minutes: 6))
        XCTAssertEqual(states[route32.id], .arrival(minutes: 9))
        XCTAssertEqual(fetchedStopIDs, [["near-stop", "near-code"]])
    }

    func testUsesNearestStopWithMatchingPrediction() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let route = busRoute(number: "100")
        let service = SavedRouteArrivalService(
            fetchPredictions: { stopIDs, _ in
                if stopIDs.contains("nearest-stop") {
                    return [
                        self.prediction(routeTag: "32", arrivalDate: Date(timeIntervalSince1970: 1_800_000_120))
                    ]
                }

                return [
                    self.prediction(routeTag: "100", arrivalDate: Date(timeIntervalSince1970: 1_800_000_420))
                ]
            },
            nearbyStopLimit: 2
        )

        let states = await service.nextArrivalStates(
            for: [route],
            currentLocation: userLocation,
            stops: [
                stop(id: "nearest-stop", latitudeOffset: 0.001),
                stop(id: "matching-stop", latitudeOffset: 0.002)
            ],
            now: now
        )

        XCTAssertEqual(states[route.id], .arrival(minutes: 7))
    }

    func testArrivalDetailsIncludeMatchingStopDistanceAndLiveSource() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let route = busRoute(number: "100")
        let service = SavedRouteArrivalService(
            fetchPredictions: { stopIDs, _ in
                if stopIDs.contains("nearest-stop") {
                    return [
                        self.prediction(routeTag: "32", arrivalDate: Date(timeIntervalSince1970: 1_800_000_120))
                    ]
                }

                return [
                    self.prediction(routeTag: "100", arrivalDate: Date(timeIntervalSince1970: 1_800_000_420))
                ]
            },
            nearbyStopLimit: 2
        )

        let details = await service.nextArrivalDetails(
            for: [route],
            currentLocation: userLocation,
            stops: [
                stop(id: "nearest-stop", latitudeOffset: 0.001),
                stop(id: "matching-stop", latitudeOffset: 0.002)
            ],
            now: now
        )

        let detail = details[route.id]
        XCTAssertEqual(detail?.state, .arrival(minutes: 7))
        XCTAssertEqual(detail?.stop?.stopID, "matching-stop")
        XCTAssertEqual(detail?.source, .live)
        XCTAssertEqual(detail?.arrivalDate, Date(timeIntervalSince1970: 1_800_000_420))
        XCTAssertEqual(detail?.distanceInMeters ?? 0, userLocation.distance(from: stop(id: "matching-stop", latitudeOffset: 0.002).location), accuracy: 0.1)
    }

    func testLimitsNearbyStopWork() async {
        let route = busRoute(number: "100")
        var fetchedStopIDs: Set<String> = []
        let service = SavedRouteArrivalService(
            fetchPredictions: { stopIDs, _ in
                fetchedStopIDs.insert(stopIDs[0])
                return []
            },
            nearbyStopLimit: 2
        )

        _ = await service.nextArrivalStates(
            for: [route],
            currentLocation: userLocation,
            stops: [
                stop(id: "first", latitudeOffset: 0.001),
                stop(id: "second", latitudeOffset: 0.002),
                stop(id: "third", latitudeOffset: 0.003)
            ]
        )

        XCTAssertEqual(fetchedStopIDs, ["first", "second"])
    }

    func testDefaultSearchWindowFindsMatchingPredictionAtTwelfthNearbyStop() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let route = busRoute(number: "32")
        let fetchRecorder = SavedRoutePredictionFetchRecorder()
        let service = SavedRouteArrivalService(
            fetchPredictions: { stopIDs, _ in
                await fetchRecorder.record(stopIDs[0])

                if stopIDs.contains("stop-12") {
                    return [
                        self.prediction(routeTag: "32", arrivalDate: Date(timeIntervalSince1970: 1_800_000_300))
                    ]
                }

                return []
            }
        )

        let stops = (1...13).map { index in
            stop(id: "stop-\(index)", latitudeOffset: Double(index) * 0.0001)
        }

        let states = await service.nextArrivalStates(
            for: [route],
            currentLocation: userLocation,
            stops: stops,
            now: now
        )

        let fetchedStopIDs = await fetchRecorder.stopIDs

        XCTAssertEqual(states[route.id], .arrival(minutes: 5))
        XCTAssertEqual(fetchedStopIDs.count, 12)
        XCTAssertFalse(fetchedStopIDs.contains("stop-13"))
    }

    func testDefaultRadiusCapSkipsStopsBeyondEightHundredMeters() async {
        let route = busRoute(number: "32")
        var predictionFetchCount = 0
        let service = SavedRouteArrivalService(
            fetchPredictions: { _, _ in
                predictionFetchCount += 1
                return [
                    self.prediction(routeTag: "32", arrivalDate: Date(timeIntervalSince1970: 1_800_000_300))
                ]
            }
        )

        let states = await service.nextArrivalStates(
            for: [route],
            currentLocation: userLocation,
            stops: [stop(id: "far-stop", latitudeOffset: 0.008)],
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(states[route.id], .unavailable)
        XCTAssertEqual(predictionFetchCount, 0)
    }

    func testTimeoutReturnsArrivalUnavailable() async {
        let route = busRoute(number: "100")
        let service = SavedRouteArrivalService(
            fetchPredictions: { _, _ in
                try await Task.sleep(nanoseconds: 200_000_000)
                return [
                    self.prediction(routeTag: "100", arrivalDate: Date(timeIntervalSince1970: 1_800_000_420))
                ]
            },
            nearbyStopLimit: 1,
            lookupTimeout: 0.01
        )

        let states = await service.nextArrivalStates(
            for: [route],
            currentLocation: userLocation,
            stops: [stop(id: "near-stop", latitudeOffset: 0.001)],
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )

        XCTAssertEqual(states[route.id], .unavailable)
    }

    func testReturnsUnavailableWhenBusTimePredictionDoesNotMatchSavedRoute() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let route = busRoute(number: "100")
        let service = SavedRouteArrivalService(
            fetchPredictions: { _, _ in
                [
                    self.prediction(routeTag: "504", arrivalDate: Date(timeIntervalSince1970: 1_800_000_420))
                ]
            }
        )

        let states = await service.nextArrivalStates(
            for: [route],
            currentLocation: userLocation,
            stops: [stop(id: "near-stop", latitudeOffset: 0.001)],
            now: now
        )

        XCTAssertEqual(states[route.id], .unavailable)
    }

    private var userLocation: CLLocation {
        CLLocation(latitude: 43.7000, longitude: -79.3500)
    }

    private func busRoute(number: String) -> TTCAlertRoute {
        TTCAlertRoute(
            name: number,
            status: "Checking status...",
            routeType: .bus,
            routeNumber: number,
            nickname: "Test Route"
        )
    }

    private func stop(
        id: String,
        stopCode: String? = nil,
        latitudeOffset: Double
    ) -> TTCStop {
        TTCStop(
            stopID: id,
            stopCode: stopCode,
            stopName: id,
            latitude: 43.7000 + latitudeOffset,
            longitude: -79.3500
        )
    }

    private func prediction(routeTag: String, arrivalDate: Date) -> TTCBusTimePrediction {
        TTCBusTimePrediction(
            routeTag: routeTag,
            routeTitle: "\(routeTag)-Test Route",
            stopTag: "stop",
            stopTitle: "Test Stop",
            directionTitle: "Test direction",
            branch: nil,
            vehicle: "1000",
            tripTag: "trip",
            arrivalDate: arrivalDate,
            seconds: nil,
            minutes: nil
        )
    }
}

private actor SavedRoutePredictionFetchRecorder {
    private var recordedStopIDs: Set<String> = []

    var stopIDs: Set<String> {
        recordedStopIDs
    }

    func record(_ stopID: String) {
        recordedStopIDs.insert(stopID)
    }
}
