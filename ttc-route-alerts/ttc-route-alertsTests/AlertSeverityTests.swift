//
//  AlertSeverityTests.swift
//  ttc-route-alertsTests
//

import XCTest
@testable import ttc_route_alerts

final class AlertSeverityTests: XCTestCase {
    func testSuspendedReturnsMajorAlert() {
        let severity = AlertSeverity.forAlertText("Service is suspended on this route.")

        XCTAssertEqual(severity, .major)
    }

    func testShuttleBusReturnsMajorAlert() {
        let severity = AlertSeverity.forAlertText("Shuttle bus service is operating.")

        XCTAssertEqual(severity, .major)
    }

    func testNoServiceReturnsMajorAlert() {
        let severity = AlertSeverity.forAlertText("There is no service between stations.")

        XCTAssertEqual(severity, .major)
    }

    func testDelayReturnsMinorAlert() {
        let severity = AlertSeverity.forAlertText("A delay is affecting this route.")

        XCTAssertEqual(severity, .minor)
    }

    func testDetourReturnsMinorAlert() {
        let severity = AlertSeverity.forAlertText("This route is on detour.")

        XCTAssertEqual(severity, .minor)
    }

    func testElevatorUnavailableReturnsMinorAlert() {
        let severity = AlertSeverity.forAlertText("Elevator unavailable at the station.")

        XCTAssertEqual(severity, .minor)
    }

    func testExistingAlertWithoutSeverityKeywordsReturnsMinorAlert() {
        let severity = AlertSeverity.forAlertText("Service alert affecting this route.")

        XCTAssertEqual(severity, .minor)
    }

    func testEmptyAlertListReturnsNormal() {
        let severity = AlertSeverity.strongestSeverity(in: [])

        XCTAssertEqual(severity, .normal)
    }
}
