//
//  RouteInputValidatorTests.swift
//  ttc-route-alertsTests
//

import XCTest
@testable import ttc_route_alerts

final class RouteInputValidatorTests: XCTestCase {
    func testBus100InputDoesNotCreateDoubleBusLabel() throws {
        let route = try validatedRoute(from: "bus 100", selectedRouteType: .bus)

        XCTAssertEqual(route.routeType, .bus)
        XCTAssertEqual(route.routeNumber, "100")
        XCTAssertFalse(route.displayName.localizedCaseInsensitiveContains("Bus Bus 100"))
    }

    func testPlain100MatchesBus100WhenSuggestionExists() throws {
        let route = try validatedRoute(from: "100", selectedRouteType: .bus)

        XCTAssertEqual(route.routeType, .bus)
        XCTAssertEqual(route.routeNumber, "100")
    }

    func testSelectedSubwayWith100SavesAsBus100WhenThatIsTheSuggestion() throws {
        let route = try validatedRoute(from: "100", selectedRouteType: .subway)

        XCTAssertEqual(route.routeType, .bus)
        XCTAssertEqual(route.routeNumber, "100")
    }

    func testInvalidRouteNumberReturnsValidationFailure() {
        let result = RouteInputValidator.validateRoute(
            routeInput: "999999",
            selectedRouteType: .bus
        )

        XCTAssertFalse(result.isValid)
        XCTAssertNil(result.route)
        XCTAssertEqual(result.errorMessage, "That doesn't look like a valid bus route.")
    }

    func testLine1MatchesSubwayLine1() throws {
        let route = try validatedRoute(from: "Line 1", selectedRouteType: .bus)

        XCTAssertEqual(route.routeType, .subway)
        XCTAssertEqual(route.routeNumber, "1")
    }

    func testStreetcar501MatchesStreetcar501() throws {
        let route = try validatedRoute(from: "streetcar 501", selectedRouteType: .bus)

        XCTAssertEqual(route.routeType, .streetcar)
        XCTAssertEqual(route.routeNumber, "501")
    }

    func testDuplicateDetectionTreatsBus100AndLowercaseBus100AsSameRoute() throws {
        let savedRoute = try validatedRoute(from: "Bus 100", selectedRouteType: .bus)
        let newRoute = try validatedRoute(from: "bus 100", selectedRouteType: .bus)

        XCTAssertTrue(RouteInputValidator.routeAlreadySaved(newRoute, in: [savedRoute]))
    }

    func testSavedRouteIsRemovedFromSuggestions() throws {
        let savedRoute = try validatedRoute(from: "Bus 100", selectedRouteType: .bus)
        let suggestions = [
            SuggestedRoute(routeID: "100", routeType: .bus, routeNumber: "100", nickname: "Broadview"),
            SuggestedRoute(routeID: "101", routeType: .bus, routeNumber: "101", nickname: "Downsview Park")
        ]

        let filteredSuggestions = RouteSuggestion.filteredSuggestions(
            from: suggestions,
            matching: "",
            selectedRouteType: .bus,
            excludingSavedRoutes: [savedRoute]
        )

        XCTAssertFalse(filteredSuggestions.contains { $0.routeNumber == "100" })
        XCTAssertTrue(filteredSuggestions.contains { $0.routeNumber == "101" })
    }

    private func validatedRoute(
        from routeInput: String,
        selectedRouteType: RouteType
    ) throws -> TTCAlertRoute {
        let result = RouteInputValidator.validateRoute(
            routeInput: routeInput,
            selectedRouteType: selectedRouteType
        )

        return try XCTUnwrap(result.route, result.errorMessage ?? "Expected route to be valid.")
    }
}
