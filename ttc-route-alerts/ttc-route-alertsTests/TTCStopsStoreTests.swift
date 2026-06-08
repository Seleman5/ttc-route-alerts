//
//  TTCStopsStoreTests.swift
//  ttc-route-alertsTests
//

import CoreLocation
import XCTest
@testable import ttc_route_alerts

final class TTCStopsStoreTests: XCTestCase {
    func testParseGTFSStopsReadsRequiredFields() {
        let stopsText = """
        stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon
        1001,,Main Street Station,,43.689000,-79.301000
        1002,,"Queen, Eastbound",,43.652000,-79.380000
        """

        let stops = TTCStopsStore.parseGTFSStops(from: stopsText)

        XCTAssertEqual(stops.count, 2)
        XCTAssertEqual(stops[0].stopID, "1001")
        XCTAssertEqual(stops[0].stopCode, nil)
        XCTAssertEqual(stops[0].stopName, "Main Street Station")
        XCTAssertEqual(stops[0].latitude, 43.689000)
        XCTAssertEqual(stops[0].longitude, -79.301000)
        XCTAssertEqual(stops[1].stopName, "Queen, Eastbound")
    }

    func testParseGTFSStopsReadsStopCodeWhenAvailable() {
        let stopsText = """
        stop_id,stop_code,stop_name,stop_desc,stop_lat,stop_lon
        platform-1001,1001,Main Street Station,,43.689000,-79.301000
        """

        let stops = TTCStopsStore.parseGTFSStops(from: stopsText)

        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops[0].stopID, "platform-1001")
        XCTAssertEqual(stops[0].stopCode, "1001")
        XCTAssertEqual(stops[0].matchingStopIDs, ["platform-1001", "1001"])
    }

    func testParseGTFSStopsSkipsInvalidRowsAndDuplicateStopIDs() {
        let stopsText = """
        stop_id,stop_name,stop_lat,stop_lon
        1001,Main Street Station,43.689000,-79.301000
        1001,Duplicate Stop,43.690000,-79.302000
        1002,Missing Longitude,43.652000,
        1003,Invalid Latitude,not-a-number,-79.380000
        """

        let stops = TTCStopsStore.parseGTFSStops(from: stopsText)

        XCTAssertEqual(stops.count, 1)
        XCTAssertEqual(stops[0].stopID, "1001")
        XCTAssertEqual(stops[0].stopName, "Main Street Station")
    }

    func testClosestStopsSortsByDistanceAndAppliesLimit() {
        let userLocation = CLLocation(latitude: 43.6500, longitude: -79.3800)
        let stops = [
            TTCStop(stopID: "far", stopName: "Far Stop", latitude: 43.7500, longitude: -79.3800),
            TTCStop(stopID: "near", stopName: "Near Stop", latitude: 43.6501, longitude: -79.3800),
            TTCStop(stopID: "middle", stopName: "Middle Stop", latitude: 43.6600, longitude: -79.3800)
        ]

        let closestStops = TTCStopsStore.closestStops(to: userLocation, from: stops, limit: 2)

        XCTAssertEqual(closestStops.map { $0.stop.stopID }, ["near", "middle"])
    }
}
