//
//  TTCAlertsService.swift
//  ttc-route-alerts
//
//  Created by Seleman Shinwarie on 2026-05-21.
//

import Foundation

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
        } catch {
            print("Could not fetch TTC alerts feed: \(error.localizedDescription)")
        }
    }
}
