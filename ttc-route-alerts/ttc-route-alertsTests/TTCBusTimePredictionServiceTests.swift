//
//  TTCBusTimePredictionServiceTests.swift
//  ttc-route-alertsTests
//

import XCTest
@testable import ttc_route_alerts

final class TTCBusTimePredictionServiceTests: XCTestCase {
    func testPredictionsParsesNVASXMLResponse() throws {
        let xml = """
        <?xml version="1.0" encoding="utf-8" ?>
        <body>
          <predictions agencyTitle="Toronto Transit Commission" routeTitle="100-Flemingdon Park" routeTag="100" stopTitle="Deauville Lane At Grenoble Dr South Side" stopTag="2655">
            <direction title="South - 100a Flemingdon Park towards Broadview Station">
              <prediction epochTime="1781033277247" seconds="660" minutes="11" isDeparture="false" branch="100A" vehicle="8806" tripTag="50394712" />
            </direction>
          </predictions>
        </body>
        """

        let predictions = try TTCBusTimePredictionService.predictions(from: Data(xml.utf8))

        XCTAssertEqual(predictions.count, 1)
        XCTAssertEqual(predictions[0].routeTag, "100")
        XCTAssertEqual(predictions[0].routeTitle, "100-Flemingdon Park")
        XCTAssertEqual(predictions[0].stopTag, "2655")
        XCTAssertEqual(predictions[0].stopTitle, "Deauville Lane At Grenoble Dr South Side")
        XCTAssertEqual(predictions[0].directionTitle, "South - 100a Flemingdon Park towards Broadview Station")
        XCTAssertEqual(predictions[0].branch, "100A")
        XCTAssertEqual(predictions[0].vehicle, "8806")
        XCTAssertEqual(predictions[0].tripTag, "50394712")
        XCTAssertEqual(predictions[0].seconds, 660)
        XCTAssertEqual(predictions[0].minutes, 11)
        XCTAssertEqual(predictions[0].arrivalDate, Date(timeIntervalSince1970: 1_781_033_277.247))
    }

    func testStopArrivalsMapsBusTimePredictionsToLiveRows() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let xml = """
        <body>
          <predictions routeTitle="100-Flemingdon Park" routeTag="100" stopTitle="Deauville Lane At Grenoble Dr South Side" stopTag="2655">
            <direction title="South - 100a Flemingdon Park towards Broadview Station">
              <prediction epochTime="1800000300000" vehicle="8806" tripTag="future-trip" />
              <prediction epochTime="1799999900000" vehicle="8807" tripTag="past-trip" />
            </direction>
          </predictions>
        </body>
        """
        let predictions = try! TTCBusTimePredictionService.predictions(from: Data(xml.utf8))
        let routesByID = [
            "100": SuggestedRoute(routeID: "100", routeType: .bus, routeNumber: "100", nickname: "Flemingdon Park")
        ]

        let arrivals = TTCBusTimePredictionService.stopArrivals(
            from: predictions,
            routesByID: routesByID,
            now: now,
            limit: 10
        )

        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(arrivals[0].routeNumber, "100")
        XCTAssertEqual(arrivals[0].routeName, "Flemingdon Park")
        XCTAssertEqual(arrivals[0].headsign, "South - 100a Flemingdon Park towards Broadview Station")
        XCTAssertEqual(arrivals[0].arrivalDate, Date(timeIntervalSince1970: 1_800_000_300))
        XCTAssertEqual(arrivals[0].source, .live)
    }

    func testStopArrivalsDeduplicatesAndLimitsPredictions() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let xml = """
        <body>
          <predictions routeTitle="100-Flemingdon Park" routeTag="100" stopTitle="Deauville Lane At Grenoble Dr South Side" stopTag="2655">
            <direction title="South - 100a Flemingdon Park towards Broadview Station">
              <prediction epochTime="1800000300000" vehicle="8806" tripTag="same-trip" />
              <prediction epochTime="1800000300000" vehicle="8806" tripTag="same-trip" />
              <prediction epochTime="1800000600000" vehicle="8807" tripTag="later-trip" />
            </direction>
          </predictions>
        </body>
        """
        let predictions = try! TTCBusTimePredictionService.predictions(from: Data(xml.utf8))

        let arrivals = TTCBusTimePredictionService.stopArrivals(
            from: predictions,
            routesByID: [:],
            now: now,
            limit: 1
        )

        XCTAssertEqual(arrivals.count, 1)
        XCTAssertEqual(arrivals[0].id, "bustime-100-2655-same-trip-1800000300")
    }
}
