//
//  RouteMatcherTests.swift
//  ttc-route-alertsTests
//

import XCTest
@testable import ttc_route_alerts

final class RouteMatcherTests: XCTestCase {
    func testRouteIDMatchSucceeds() {
        let route = savedRoute(routeID: "34", routeNumber: "34", nickname: "Eglinton East")
        let alert = TTCAlert(text: "A service alert exists for this route.", routeIDs: ["34"])

        XCTAssertTrue(RouteMatcher.matches(alert, route: route))
    }

    func testRouteIDMismatchFallsBackToTextMatching() {
        let route = savedRoute(routeID: "34", routeNumber: "34", nickname: "Eglinton East")
        let alert = TTCAlert(text: "Delay reported on Route 34 Eglinton East.", routeIDs: ["999"])

        XCTAssertTrue(RouteMatcher.matches(alert, route: route))
    }

    func testBus34DoesNotMatch134Or934() {
        let route = savedRoute(routeID: "34", routeNumber: "34", nickname: "Eglinton East")
        let alert = TTCAlert(text: "Delays reported on routes 134 and 934.", routeIDs: ["134", "934"])

        XCTAssertFalse(RouteMatcher.matches(alert, route: route))
    }

    func testBus131MatchesAlertMentioning131Nugget() {
        let route = savedRoute(routeID: "131", routeNumber: "131", nickname: "Nugget")
        let alert = TTCAlert(text: "Delay on 131 Nugget.", routeIDs: [])

        XCTAssertTrue(RouteMatcher.matches(alert, route: route))
    }

    func testSubwayLine1MatchesLine1AndYongeUniversityText() {
        let route = savedRoute(routeType: .subway, routeID: "1", routeNumber: "1", nickname: "Yonge-University")
        let lineAlert = TTCAlert(text: "Service delay on Line 1.", routeIDs: [])
        let nameAlert = TTCAlert(text: "Service delay on Yonge-University.", routeIDs: [])

        XCTAssertTrue(RouteMatcher.matches(lineAlert, route: route))
        XCTAssertTrue(RouteMatcher.matches(nameAlert, route: route))
    }

    func testNicknameFallbackWorks() {
        let route = savedRoute(routeID: nil, routeNumber: "501", nickname: "Queen")
        let alert = TTCAlert(text: "Streetcars are delayed on Queen.", routeIDs: [])

        XCTAssertTrue(RouteMatcher.matches(alert, route: route))
    }

    func testNoFalseMatchReturnsFalse() {
        let route = savedRoute(routeID: "34", routeNumber: "34", nickname: "Eglinton East")
        let alert = TTCAlert(text: "Delay on Line 2 Bloor-Danforth.", routeIDs: ["2"])

        XCTAssertFalse(RouteMatcher.matches(alert, route: route))
    }

    private func savedRoute(
        routeType: RouteType = .bus,
        routeID: String?,
        routeNumber: String,
        nickname: String
    ) -> TTCAlertRoute {
        TTCAlertRoute(
            name: routeNumber,
            status: "Checking status...",
            routeID: routeID,
            routeType: routeType,
            routeNumber: routeNumber,
            nickname: nickname
        )
    }
}
