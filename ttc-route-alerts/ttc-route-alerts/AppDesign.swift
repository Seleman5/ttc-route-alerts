//
//  AppDesign.swift
//  ttc-route-alerts
//

import SwiftUI

enum AppDesign {
    static let ttcRed = Color(red: 0.85, green: 0.06, blue: 0.10)
    static let appBackground = Color(.systemGroupedBackground)
    static let cardBackground = Color(.secondarySystemGroupedBackground)
    static let insetBackground = Color(.tertiarySystemGroupedBackground)
    static let fieldBackground = Color(.systemGray6)

    static let cardRadius: CGFloat = 18
    static let smallRadius: CGFloat = 12
    static let iconRadius: CGFloat = 8
    static let cardPadding: CGFloat = 18
    static let screenHorizontalPadding: CGFloat = 20
    static let sectionSpacing: CGFloat = 24

    static let softShadow = Color.black.opacity(0.045)
    static let subtleBorder = Color.primary.opacity(0.06)
    static let subtleAnimation = Animation.easeInOut(duration: 0.22)

    static func routeIconName(for routeType: RouteType?) -> String {
        switch routeType {
        case .bus:
            return "bus.fill"
        case .streetcar:
            return "tram.fill"
        case .subway:
            return "train.side.front.car"
        case nil:
            return "arrow.triangle.branch"
        }
    }

    static func routeAccentColor(for routeType: RouteType?) -> Color {
        switch routeType {
        case .bus:
            return Color(red: 0.18, green: 0.42, blue: 0.72)
        case .streetcar:
            return Color(red: 0.82, green: 0.38, blue: 0.12)
        case .subway:
            return ttcRed
        case nil:
            return ttcRed
        }
    }

    static func routeAccentBackground(for routeType: RouteType?) -> Color {
        routeAccentColor(for: routeType).opacity(0.10)
    }
}

extension View {
    func appCardStyle(
        padding: CGFloat = AppDesign.cardPadding,
        cornerRadius: CGFloat = AppDesign.cardRadius
    ) -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(AppDesign.cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppDesign.subtleBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .shadow(color: AppDesign.softShadow, radius: 14, x: 0, y: 5)
    }
}
