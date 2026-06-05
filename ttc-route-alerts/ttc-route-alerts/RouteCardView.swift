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
        HStack(alignment: .center, spacing: 14) {
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
                    .fixedSize(horizontal: false, vertical: true)

                StatusBadgeView(severity: severity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)
        }
        .appCardStyle(padding: 15)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(route.displayName), \(severity.rawValue)")
    }
}
