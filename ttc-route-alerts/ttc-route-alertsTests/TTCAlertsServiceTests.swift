//
//  TTCAlertsServiceTests.swift
//  ttc-route-alertsTests
//

import XCTest
@testable import ttc_route_alerts

final class TTCAlertsServiceTests: XCTestCase {
    func testDeduplicatedAlertsPrefersLongerDescriptionForSameIssue() {
        let shortAlert = TTCAlert(
            text: "131 Nugget: Detour.",
            routeIDs: ["131"]
        )
        let longerAlert = TTCAlert(
            text: "131 Nugget: Detour due to construction between Scarborough Centre and Old Finch.",
            routeIDs: ["131"]
        )

        let alerts = TTCAlertsService.deduplicatedAlerts([shortAlert, longerAlert])

        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.text, longerAlert.text)
    }

    func testDeduplicatedAlertsKeepsDifferentRoutesSeparate() {
        let bus131Alert = TTCAlert(text: "Detour due to construction.", routeIDs: ["131"])
        let bus100Alert = TTCAlert(text: "Detour due to construction.", routeIDs: ["100"])

        let alerts = TTCAlertsService.deduplicatedAlerts([bus131Alert, bus100Alert])

        XCTAssertEqual(alerts.count, 2)
    }

    func testBestAlertTextKeeps131NuggetWhenDescriptionDoesNotRepeatRouteName() {
        let alertText = TTCAlertsService().bestAlertText(from: [
            "131 Nugget: Detour via Markham Rd.",
            "Detour via Markham Rd, Sheppard Ave E and Shorting Rd due to a collision."
        ])

        XCTAssertEqual(
            alertText,
            "131 Nugget: Detour via Markham Rd. Detour via Markham Rd, Sheppard Ave E and Shorting Rd due to a collision."
        )
    }
}
