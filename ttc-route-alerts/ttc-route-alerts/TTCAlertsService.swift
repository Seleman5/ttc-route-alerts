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

    func fetchAlertsFeed() async {
        do {
            let (data, response) = try await URLSession.shared.data(from: alertsFeedURL)

            if let httpResponse = response as? HTTPURLResponse {
                print("TTC alerts feed status: \(httpResponse.statusCode)")
            } else {
                print("TTC alerts feed response was not an HTTP response")
            }

            print("TTC alerts feed data size: \(data.count) bytes")
            printDecodedAlerts(from: data)
        } catch {
            print("Could not fetch TTC alerts feed: \(error.localizedDescription)")
        }
    }

    func printDecodedAlerts(from data: Data) {
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
        } catch {
            print("Could not decode TTC alerts feed: \(error.localizedDescription)")
        }
    }

    func readableAlertTexts(from feed: TransitRealtime_FeedMessage) -> [String] {
        var alertTexts: [String] = []

        for entity in feed.entity {
            guard entity.hasAlert else {
                continue
            }

            let alert = entity.alert

            if alert.hasHeaderText {
                alertTexts.append(contentsOf: texts(from: alert.headerText))
            }

            if alert.hasDescriptionText {
                alertTexts.append(contentsOf: texts(from: alert.descriptionText))
            }
        }

        return alertTexts
    }

    func texts(from translatedString: TransitRealtime_TranslatedString) -> [String] {
        translatedString.translation
            .map(\.text)
            .filter { !$0.isEmpty }
    }
}
