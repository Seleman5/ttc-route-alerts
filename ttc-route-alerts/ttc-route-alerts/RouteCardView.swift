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
        HStack(spacing: 13) {
            RoundedRectangle(cornerRadius: AppDesign.iconRadius)
                .fill(ttcRed.opacity(0.09))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: AppDesign.routeIconName(for: route.routeType))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(ttcRed)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(route.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)

                StatusBadgeView(severity: severity)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .appCardStyle(padding: 16)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(route.displayName), \(severity.rawValue)")
    }
}
