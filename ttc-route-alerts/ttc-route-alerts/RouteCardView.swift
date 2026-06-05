//
//  RouteCardView.swift
//  ttc-route-alerts
//

import SwiftUI

struct RouteCardView: View {
    let route: TTCAlertRoute
    let severity: AlertSeverity
    let ttcRed: Color

    var body: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(ttcRed)
                .frame(width: 42, height: 42)
                .overlay {
                    Image(systemName: "tram.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(route.displayName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                StatusBadgeView(severity: severity)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(route.displayName), \(severity.rawValue)")
    }
}
