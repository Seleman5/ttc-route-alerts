//
//  StatusBadgeView.swift
//  ttc-route-alerts
//

import SwiftUI

struct StatusBadgeView: View {
    let severity: AlertSeverity

    var body: some View {
        Text(severity.rawValue)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(severity.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(severity.backgroundColor)
            .clipShape(Capsule())
            .contentTransition(.opacity)
            .animation(AppDesign.subtleAnimation, value: severity.rawValue)
    }
}
