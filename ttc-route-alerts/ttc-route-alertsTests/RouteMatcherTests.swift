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

    func testBus131TextFallbackMatchesExactNuggetDetourAndSeverityIsNotNormal() {
        let route = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")
        let alert = TTCAlert(
            text: "131 Nugget: Detour via Markham Rd, Sheppard Ave E and Shorting Rd due to a collision.",
            routeIDs: ["999"]
        )
        let matchingAlerts = RouteAlertStatus.matchingAlerts(for: route, in: [alert])
        let severity = RouteAlertStatus.severity(for: route, in: [alert])

        XCTAssertTrue(RouteMatcher.matches(alert, route: route))
        XCTAssertEqual(matchingAlerts, [alert])
        XCTAssertNotEqual(severity, .normal)
    }

    func testBus131DoesNotMatchLine5EglintonAlert() {
        let route = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")
        let alert = TTCAlert(
            text: "Line 5 Eglinton: Elevator unavailable at Kennedy Station. Customers can connect to nearby bus routes.",
            routeIDs: ["5"]
        )
        let matchingAlerts = RouteAlertStatus.matchingAlerts(for: route, in: [alert])
        let severity = RouteAlertStatus.severity(for: route, in: [alert])

        XCTAssertFalse(RouteMatcher.matches(alert, route: route))
        XCTAssertTrue(matchingAlerts.isEmpty)
        XCTAssertEqual(severity, .normal)
    }

    func testBus100DoesNotMatchLine5StationAlert() {
        let route = savedRoute(routeID: "100_1", routeNumber: "100", nickname: "Broadview Station to Flemingdon Park")
        let alert = TTCAlert(
            text: "Line 5 Eglinton: Elevator unavailable at Kennedy Station. Customers can connect to nearby bus routes.",
            routeIDs: ["5"]
        )
        let matchingAlerts = RouteAlertStatus.matchingAlerts(for: route, in: [alert])
        let severity = RouteAlertStatus.severity(for: route, in: [alert])

        XCTAssertFalse(RouteMatcher.matches(alert, route: route))
        XCTAssertTrue(matchingAlerts.isEmpty)
        XCTAssertEqual(severity, .normal)
    }

    func testBus100DoesNotMatchLine5StationAlertEvenWithBusRouteID() {
        let route = savedRoute(routeID: "100_1", routeNumber: "100", nickname: "Broadview Station to Flemingdon Park")
        let alert = TTCAlert(
            text: "Line 5 Eglinton: Elevator unavailable at Kennedy Station. Customers can connect to nearby bus routes.",
            routeIDs: ["100"]
        )

        XCTAssertFalse(RouteMatcher.matches(alert, route: route))
    }

    func testBus131DoesNotMatchLine5StationAlertEvenWithBusRouteID() {
        let route = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")
        let alert = TTCAlert(
            text: "Line 5 Eglinton: Elevator unavailable at Kennedy Station. Customers can connect to nearby bus routes.",
            routeIDs: ["131"]
        )

        XCTAssertFalse(RouteMatcher.matches(alert, route: route))
    }

    func testBus131DoesNotMatchLine5RouteIDThatContains131Later() {
        let route = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")
        let alert = TTCAlert(
            text: "Line 5 Eglinton: Service is delayed between Mount Dennis and Kennedy.",
            routeIDs: ["5_131"]
        )

        XCTAssertFalse(RouteMatcher.matches(alert, route: route))
    }

    func testBus131MatchesRealisticBaseAndBranchRouteIDs() {
        let route = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")

        XCTAssertTrue(RouteMatcher.matches(TTCAlert(text: "Service alert for this route.", routeIDs: ["131"]), route: route))
        XCTAssertTrue(RouteMatcher.matches(TTCAlert(text: "Service alert for this route.", routeIDs: ["131A"]), route: route))
        XCTAssertTrue(RouteMatcher.matches(TTCAlert(text: "Service alert for this route.", routeIDs: ["131B"]), route: route))
    }

    func testBus131DoesNotMatchUnrelatedRouteIDs() {
        let route = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")

        XCTAssertFalse(RouteMatcher.matches(TTCAlert(text: "Service alert for this route.", routeIDs: ["5"]), route: route))
        XCTAssertFalse(RouteMatcher.matches(TTCAlert(text: "Service alert for this route.", routeIDs: ["5_1"]), route: route))
        XCTAssertFalse(RouteMatcher.matches(TTCAlert(text: "Service alert for this route.", routeIDs: ["1131"]), route: route))
        XCTAssertFalse(RouteMatcher.matches(TTCAlert(text: "Service alert for this route.", routeIDs: ["1310"]), route: route))
    }

    func testBus131CachedAlertsStayIsolatedFromLine5Alert() {
        let bus131 = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")
        let bus131Alert = TTCAlert(
            text: "131 Nugget: Detour via Markham Rd, Sheppard Ave E and Shorting Rd due to a collision.",
            routeIDs: ["999"]
        )
        let line5Alert = TTCAlert(
            text: "Line 5 Eglinton: Service is delayed between Mount Dennis and Kennedy.",
            routeIDs: ["5"]
        )
        let matchingAlerts = RouteAlertStatus.matchingAlerts(
            for: bus131,
            cachedAlerts: [bus131Alert, line5Alert],
            allAlerts: [bus131Alert, line5Alert]
        )

        XCTAssertEqual(matchingAlerts, [bus131Alert])
    }

    func testEmptyRouteAlertCacheDoesNotFallBackToOldAlerts() {
        let bus131 = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")
        let oldBus131Alert = TTCAlert(
            text: "131 Nugget: Detour via Markham Rd, Sheppard Ave E and Shorting Rd due to a collision.",
            routeIDs: ["131"]
        )

        let matchingAlerts = RouteAlertStatus.matchingAlerts(
            for: bus131,
            cachedAlerts: [],
            allAlerts: [oldBus131Alert]
        )

        XCTAssertTrue(matchingAlerts.isEmpty)
    }

    func testDisappearedAlertReturnsNormalWithLatestFeed() {
        let bus131 = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")
        let oldBus131Alert = TTCAlert(
            text: "131 Nugget: Detour via Markham Rd, Sheppard Ave E and Shorting Rd due to a collision.",
            routeIDs: ["131"]
        )

        XCTAssertEqual(RouteAlertStatus.severity(for: bus131, in: [oldBus131Alert]), .minor)
        XCTAssertEqual(RouteAlertStatus.severity(for: bus131, in: []), .normal)
    }

    func testSubwayLine5MatchesLine5EglintonAlert() {
        let line5 = savedRoute(routeType: .subway, routeID: "5", routeNumber: "5", nickname: "Eglinton")
        let alert = TTCAlert(
            text: "Line 5 Eglinton: Service is delayed between Mount Dennis and Kennedy.",
            routeIDs: ["5"]
        )

        XCTAssertTrue(RouteMatcher.matches(alert, route: line5))
    }

    func testBus131MatchesBranchStyleRouteID() {
        let route = savedRoute(routeID: "131_1", routeNumber: "131", nickname: "Nugget")
        let alert = TTCAlert(text: "A service alert exists for this branch.", routeIDs: ["131A"])

        XCTAssertTrue(RouteMatcher.matches(alert, route: route))
    }

    func testBus131TextFallbackWorksWhenRouteIDIsMissing() {
        let route = savedRoute(routeID: nil, routeNumber: "131", nickname: "Nugget")
        let alert = TTCAlert(text: "131 Nugget: Service change.", routeIDs: [])

        XCTAssertTrue(RouteMatcher.matches(alert, route: route))
    }

    func testSubwayLine1MatchesLine1AndYongeUniversityText() {
        let route = savedRoute(routeType: .subway, routeID: "1", routeNumber: "1", nickname: "Yonge-University")
        let lineAlert = TTCAlert(text: "Service delay on Line 1.", routeIDs: [])
        let nameAlert = TTCAlert(text: "Service delay on Yonge-University.", routeIDs: [])

        XCTAssertTrue(RouteMatcher.matches(lineAlert, route: route))
        XCTAssertTrue(RouteMatcher.matches(nameAlert, route: route))
    }

    func testSubwayNicknameFallbackWorks() {
        let route = savedRoute(routeType: .subway, routeID: "2", routeNumber: "2", nickname: "Bloor-Danforth")
        let alert = TTCAlert(text: "Service delay on Bloor-Danforth.", routeIDs: [])

        XCTAssertTrue(RouteMatcher.matches(alert, route: route))
    }

    func testStreetcarDoesNotUseNicknameFallback() {
        let route = savedRoute(routeID: nil, routeNumber: "501", nickname: "Queen")
        let alert = TTCAlert(text: "Streetcars are delayed on Queen.", routeIDs: [])

        XCTAssertFalse(RouteMatcher.matches(alert, route: route))
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
