//
//  RouteCardView.swift
//  ttc-route-alerts
//

import SwiftUI

struct RouteCardView: View {
    let route: TTCAlertRoute
    let severity: AlertSeverity

    var body: some View {
        let accentColor = AppDesign.routeAccentColor(for: route.routeType)

        HStack(alignment: .center, spacing: 14) {
            RoundedRectangle(cornerRadius: AppDesign.iconRadius)
                .fill(AppDesign.routeAccentBackground(for: route.routeType))
                .frame(width: 40, height: 40)
                .overlay {
                    Image(systemName: AppDesign.routeIconName(for: route.routeType))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(accentColor)
                }

            VStack(alignment: .leading, spacing: 8) {
                Text(route.displayName)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .lineSpacing(1)
                    .fixedSize(horizontal: false, vertical: true)

                StatusBadgeView(severity: severity)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 8)
        }
        .appCardStyle(padding: 15)
        .animation(AppDesign.subtleAnimation, value: severity.rawValue)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(route.displayName), \(severity.rawValue)")
    }
}
