//
//  RouteAlertNotificationManagerTests.swift
//  ttc-route-alertsTests
//

import XCTest
@testable import ttc_route_alerts

final class RouteAlertNotificationManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        RouteAlertNotificationManager.resetSeenAlertNotificationKeysForTesting()
    }

    override func tearDown() {
        RouteAlertNotificationManager.resetSeenAlertNotificationKeysForTesting()
        super.tearDown()
    }

    func testNewAlertNotifiesOnlyOnceUntilItClears() {
        let route = bus131Route()
        let alert = nuggetDetourAlert()

        let firstRefreshNotifications = RouteAlertNotificationManager.newAlertNotifications(
            for: route,
            matchingAlerts: [alert]
        )

        XCTAssertEqual(firstRefreshNotifications.count, 1)
        XCTAssertEqual(firstRefreshNotifications.first?.severity, .minor)

        let repeatedRefreshNotifications = RouteAlertNotificationManager.newAlertNotifications(
            for: route,
            matchingAlerts: [alert]
        )

        XCTAssertTrue(repeatedRefreshNotifications.isEmpty)

        let clearedRefreshNotifications = RouteAlertNotificationManager.newAlertNotifications(
            for: route,
            matchingAlerts: []
        )

        XCTAssertTrue(clearedRefreshNotifications.isEmpty)

        let reappearingAlertNotifications = RouteAlertNotificationManager.newAlertNotifications(
            for: route,
            matchingAlerts: [alert]
        )

        XCTAssertEqual(reappearingAlertNotifications.count, 1)
    }

    func testDuplicateMatchingAlertsOnlyCreateOneNotification() {
        let route = bus131Route()
        let alert = nuggetDetourAlert()

        let notifications = RouteAlertNotificationManager.newAlertNotifications(
            for: route,
            matchingAlerts: [alert, alert]
        )

        XCTAssertEqual(notifications.count, 1)
    }

    func testNotificationBodyIncludesRouteSeverityAndAlertText() throws {
        let route = bus131Route()
        let alert = nuggetDetourAlert()
        let notification = try XCTUnwrap(
            RouteAlertNotificationManager.newAlertNotifications(
                for: route,
                matchingAlerts: [alert]
            )
            .first
        )

        let body = RouteAlertNotificationManager.notificationBody(for: notification)

        XCTAssertTrue(body.contains("Bus 131 has a Minor Alert"))
        XCTAssertTrue(body.contains("131 Nugget"))
    }

    private func bus131Route() -> TTCAlertRoute {
        TTCAlertRoute(
            id: UUID(uuidString: "13100000-0000-0000-0000-000000000000")!,
            name: "131",
            status: "Checking status...",
            routeID: "131",
            routeType: .bus,
            routeNumber: "131",
            nickname: "Nugget"
        )
    }

    private func nuggetDetourAlert() -> TTCAlert {
        TTCAlert(
            text: "131 Nugget: Detour via Markham Rd, Sheppard Ave E and Shorting Rd due to a collision.",
            routeIDs: ["131"]
        )
    }
}
