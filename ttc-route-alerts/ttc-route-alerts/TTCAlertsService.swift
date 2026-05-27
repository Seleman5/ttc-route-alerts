//
//  TTCAlertsService.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-21.
//

import Foundation
import SwiftProtobuf

struct TTCAlert: Hashable {
    let text: String
    let routeIDs: [String]
}

struct TTCAlertsService {
    let alertsFeedURL = URL(string: "https://bustime.ttc.ca/gtfsrt/alerts")!

    func fetchAlertsFeed() async throws -> [TTCAlert] {
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

    func decodedAlerts(from data: Data) throws -> [TTCAlert] {
        do {
            let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
            let alerts = readableAlerts(from: feed)

            print("Decoded TTC alerts: \(alerts.count)")

            if alerts.isEmpty {
                print("No readable TTC alert text found in the feed.")
            } else {
                for alert in alerts {
                    print("TTC alert: \(alert.text)")
                }
            }

            return alerts
        } catch {
            print("Could not decode TTC alerts feed: \(error.localizedDescription)")
            throw error
        }
    }

    func readableAlerts(from feed: TransitRealtime_FeedMessage) -> [TTCAlert] {
        var alerts: [TTCAlert] = []

        for entity in feed.entity {
            guard entity.hasAlert else {
                continue
            }

            let alert = entity.alert
            let routeIDs = routeIDs(from: alert)

            if alert.hasHeaderText {
                alerts.append(contentsOf: alertsFromTranslations(alert.headerText, routeIDs: routeIDs))
            }

            if alert.hasDescriptionText {
                alerts.append(contentsOf: alertsFromTranslations(alert.descriptionText, routeIDs: routeIDs))
            }
        }

        return alerts
    }

    func alertsFromTranslations(_ translatedString: TransitRealtime_TranslatedString, routeIDs: [String]) -> [TTCAlert] {
        translatedString.translation
            .map(\.text)
            .filter { !$0.isEmpty }
            .map { text in
                TTCAlert(text: text, routeIDs: routeIDs)
            }
    }

    func routeIDs(from alert: TransitRealtime_Alert) -> [String] {
        var routeIDs: [String] = []

        for informedEntity in alert.informedEntity {
            if informedEntity.hasRouteID {
                routeIDs.append(informedEntity.routeID)
            }

            if informedEntity.hasTrip, informedEntity.trip.hasRouteID {
                routeIDs.append(informedEntity.trip.routeID)
            }
        }

        return routeIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .reduce(into: []) { uniqueRouteIDs, routeID in
                if !uniqueRouteIDs.contains(routeID) {
                    uniqueRouteIDs.append(routeID)
                }
            }
    }
}
