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
            fetchPredictions: { _ in
                predictionFetchCount += 1
                return []
            },
            fetchRouteIDsServingStop: { _ in
                .success(["1"])
            }
        )

        let state = await service.nextArrivalState(
            for: route,
            currentLocation: userLocation,
            stops: [stop(id: "stop-1", latitudeOffset: 0.001)]
        )

        XCTAssertEqual(state, .unavailable)
        XCTAssertEqual(predictionFetchCount, 0)
    }

    func testUsesNearestStaticStopServedBySavedRoute() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let route = busRoute(number: "100")
        var fetchedStopIDs: [[String]] = []
        let service = SavedRouteArrivalService(
            fetchPredictions: { stopIDs in
                fetchedStopIDs.append(stopIDs)
                return [
                    self.prediction(routeTag: "100", arrivalDate: Date(timeIntervalSince1970: 1_800_000_360))
                ]
            },
            fetchRouteIDsServingStop: { stopID in
                stopID == "served-stop" ? .success(["route-100"]) : .success(["route-504"])
            }
        )

        let state = await service.nextArrivalState(
            for: route,
            currentLocation: userLocation,
            stops: [
                stop(id: "other-stop", latitudeOffset: 0.001),
                stop(id: "served-stop", stopCode: "served-code", latitudeOffset: 0.002)
            ],
            now: now
        )

        XCTAssertEqual(state, .arrival(minutes: 6))
        XCTAssertEqual(fetchedStopIDs, [["served-stop", "served-code"]])
    }

    func testFallsBackToBusTimeMatchingWhenStaticValidationIsUnavailable() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let service = SavedRouteArrivalService(
            fetchPredictions: { _ in
                [
                    self.prediction(routeTag: "100", arrivalDate: Date(timeIntervalSince1970: 1_800_000_420))
                ]
            },
            fetchRouteIDsServingStop: { _ in
                .failure(.missingFile("stop_times.txt"))
            }
        )

        let state = await service.nextArrivalState(
            for: busRoute(number: "100"),
            currentLocation: userLocation,
            stops: [stop(id: "near-stop", latitudeOffset: 0.001)],
            now: now
        )

        XCTAssertEqual(state, .arrival(minutes: 7))
    }

    func testReturnsUnavailableWhenBusTimePredictionDoesNotMatchSavedRoute() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let service = SavedRouteArrivalService(
            fetchPredictions: { _ in
                [
                    self.prediction(routeTag: "504", arrivalDate: Date(timeIntervalSince1970: 1_800_000_420))
                ]
            },
            fetchRouteIDsServingStop: { _ in
                .failure(.missingFile("stop_times.txt"))
            }
        )

        let state = await service.nextArrivalState(
            for: busRoute(number: "100"),
            currentLocation: userLocation,
            stops: [stop(id: "near-stop", latitudeOffset: 0.001)],
            now: now
        )

        XCTAssertEqual(state, .unavailable)
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
            nickname: "Flemingdon Park"
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
