//
//  AlertSeverity.swift
//  ttc-route-alerts
//

import SwiftUI

enum AlertSeverity: String {
    case normal = "Normal"
    case minor = "Minor Alert"
    case major = "Major Alert"

    var priority: Int {
        switch self {
        case .normal:
            return 0
        case .minor:
            return 1
        case .major:
            return 2
        }
    }

    var textColor: Color {
        switch self {
        case .normal:
            return .green
        case .minor:
            return .orange
        case .major:
            return .red
        }
    }

    var backgroundColor: Color {
        switch self {
        case .normal:
            return Color.green.opacity(0.14)
        case .minor:
            return Color.orange.opacity(0.16)
        case .major:
            return Color.red.opacity(0.12)
        }
    }

    static func forAlertText(_ alertText: String) -> AlertSeverity {
        let lowercaseAlert = alertText.lowercased()
        let majorKeywords = ["suspended", "closure", "shuttle bus", "no service"]
        let minorKeywords = ["delay", "detour", "elevator", "escalator", "unavailable"]

        if majorKeywords.contains(where: { lowercaseAlert.contains($0) }) {
            return .major
        }

        if minorKeywords.contains(where: { lowercaseAlert.contains($0) }) {
            return .minor
        }

        return .minor
    }

    static func strongestSeverity(in alerts: [String]) -> AlertSeverity {
        guard !alerts.isEmpty else {
            return .normal
        }

        var strongestSeverity = AlertSeverity.minor

        for alert in alerts {
            let alertSeverity = AlertSeverity.forAlertText(alert)

            if alertSeverity.priority > strongestSeverity.priority {
                strongestSeverity = alertSeverity
            }
        }

        return strongestSeverity
    }
}
