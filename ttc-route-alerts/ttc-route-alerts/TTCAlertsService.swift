//
//  TTCAlertsService.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-21.
//

import Foundation
import SwiftProtobuf

struct TTCAlertsService {
    let alertsFeedURL = URL(string: "https://bustime.ttc.ca/gtfsrt/alerts")!

    func fetchAlertsFeed() async throws -> [String] {
        let (data, response) = try await URLSession.shared.data(from: alertsFeedURL)

        if let httpResponse = response as? HTTPURLResponse {
            print("TTC alerts feed status: \(httpResponse.statusCode)")

            guard (200...299).contains(httpResponse.statusCode) else {
                throw URLError(.badServerResponse)
            }
        } else {
            print("TTC alerts feed response was not an HTTP response")
            throw URLError(.badServerResponse)
        }

        print("TTC alerts feed data size: \(data.count) bytes")
        return try decodedAlerts(from: data)
    }

    func decodedAlerts(from data: Data) throws -> [String] {
        do {
            let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
            let alertTexts = readableAlertTexts(from: feed)

            print("Decoded TTC alerts: \(alertTexts.count)")

            if alertTexts.isEmpty {
                print("No readable TTC alert text found in the feed.")
            } else {
                for alertText in alertTexts {
                    print("TTC alert: \(alertText)")
                }
            }

            return alertTexts
        } catch {
            print("Could not decode TTC alerts feed: \(error.localizedDescription)")
            throw error
        }
    }

    func readableAlertTexts(from feed: TransitRealtime_FeedMessage) -> [String] {
        var alertTexts: [String] = []

        for entity in feed.entity {
            guard entity.hasAlert else {
                continue
            }

            let alert = entity.alert
            logAlertMetadata(alert, entityID: entity.id)

            if alert.hasHeaderText {
                alertTexts.append(contentsOf: texts(from: alert.headerText))
            }

            if alert.hasDescriptionText {
                alertTexts.append(contentsOf: texts(from: alert.descriptionText))
            }
        }

        return alertTexts
    }

    func logAlertMetadata(_ alert: TransitRealtime_Alert, entityID: String) {
        print("TTC alert metadata debug")
        print("Entity ID: \(entityID)")

        if alert.hasHeaderText {
            print("Header text: \(texts(from: alert.headerText).joined(separator: " | "))")
        } else {
            print("Header text: none")
        }

        if alert.hasDescriptionText {
            print("Description text: \(texts(from: alert.descriptionText).joined(separator: " | "))")
        } else {
            print("Description text: none")
        }

        if alert.informedEntity.isEmpty {
            print("Informed entities: none")
        }

        for (index, informedEntity) in alert.informedEntity.enumerated() {
            let routeID = informedEntity.hasRouteID ? informedEntity.routeID : "none"
            let stopID = informedEntity.hasStopID ? informedEntity.stopID : "none"
            let tripRouteID = informedEntity.hasTrip && informedEntity.trip.hasRouteID ? informedEntity.trip.routeID : "none"

            print("Informed entity \(index + 1) routeID: \(routeID)")
            print("Informed entity \(index + 1) stopID: \(stopID)")
            print("Informed entity \(index + 1) trip routeID: \(tripRouteID)")
        }
    }

    func texts(from translatedString: TransitRealtime_TranslatedString) -> [String] {
        translatedString.translation
            .map(\.text)
            .filter { !$0.isEmpty }
    }
}
