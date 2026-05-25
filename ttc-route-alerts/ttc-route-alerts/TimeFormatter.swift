//
//  TimeFormatter.swift
//  ttc-route-alerts
//

import Foundation

enum TimeFormatter {
    static func lastUpdatedText(for date: Date, now: Date = Date()) -> String {
        let secondsAgo = max(0, Int(now.timeIntervalSince(date)))
        let minutesAgo = secondsAgo / 60
        let hoursAgo = minutesAgo / 60

        if secondsAgo < 60 {
            return "Updated just now"
        } else if minutesAgo < 60 {
            return "Updated \(minutesAgo) min ago"
        } else if hoursAgo < 24 {
            return "Updated \(hoursAgo) hr ago"
        } else {
            return "Updated \(date.formatted(date: .abbreviated, time: .shortened))"
        }
    }
}
