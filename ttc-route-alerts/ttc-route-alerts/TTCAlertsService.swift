//
//  TTCAlertsService.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-21.
//

import Foundation
import SwiftProtobuf

struct TTCAlert: Codable, Hashable {
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
            var alertTexts: [String] = []

            if alert.hasHeaderText {
                alertTexts.append(contentsOf: textsFromTranslations(alert.headerText))
            }

            if alert.hasDescriptionText {
                alertTexts.append(contentsOf: textsFromTranslations(alert.descriptionText))
            }

            if let bestText = bestAlertText(from: alertTexts) {
                alerts.append(TTCAlert(text: bestText, routeIDs: routeIDs))
            }
        }

        return Self.deduplicatedAlerts(alerts)
    }

    func alertsFromTranslations(_ translatedString: TransitRealtime_TranslatedString, routeIDs: [String]) -> [TTCAlert] {
        textsFromTranslations(translatedString)
            .map { text in
                TTCAlert(text: text, routeIDs: routeIDs)
            }
    }

    func textsFromTranslations(_ translatedString: TransitRealtime_TranslatedString) -> [String] {
        translatedString.translation
            .map(\.text)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func bestAlertText(from texts: [String]) -> String? {
        let uniqueTexts = texts
            .reduce(into: [String]()) { uniqueTexts, text in
                if !uniqueTexts.contains(where: { Self.normalizedAlertText($0) == Self.normalizedAlertText(text) }) {
                    uniqueTexts.append(text)
                }
            }

        let usefulTexts = uniqueTexts.filter { text in
            let normalizedText = Self.normalizedAlertText(text)

            return !uniqueTexts.contains { otherText in
                let normalizedOtherText = Self.normalizedAlertText(otherText)
                return normalizedOtherText != normalizedText
                    && normalizedOtherText.contains(normalizedText)
            }
        }

        guard !usefulTexts.isEmpty else {
            return nil
        }

        return usefulTexts.joined(separator: " ")
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

    static func deduplicatedAlerts(_ alerts: [TTCAlert]) -> [TTCAlert] {
        var deduplicatedAlerts: [TTCAlert] = []

        for alert in alerts {
            if let existingIndex = deduplicatedAlerts.firstIndex(where: { isSameIssue($0, alert) }) {
                if alert.text.count > deduplicatedAlerts[existingIndex].text.count {
                    deduplicatedAlerts[existingIndex] = alert
                }
            } else {
                deduplicatedAlerts.append(alert)
            }
        }

        return deduplicatedAlerts
    }

    static func normalizedAlertText(_ text: String) -> String {
        text
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func isSameIssue(_ firstAlert: TTCAlert, _ secondAlert: TTCAlert) -> Bool {
        guard routeIDKey(for: firstAlert.routeIDs) == routeIDKey(for: secondAlert.routeIDs) else {
            return false
        }

        let firstText = normalizedAlertText(firstAlert.text)
        let secondText = normalizedAlertText(secondAlert.text)

        return firstText == secondText
            || firstText.contains(secondText)
            || secondText.contains(firstText)
    }

    private static func routeIDKey(for routeIDs: [String]) -> String {
        routeIDs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
            .sorted()
            .joined(separator: "|")
    }
}
