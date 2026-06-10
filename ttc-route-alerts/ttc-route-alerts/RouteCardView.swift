//
//  RouteCardView.swift
//  ttc-route-alerts
//

import SwiftUI

struct RouteCardView: View {
    let route: TTCAlertRoute
    let severity: AlertSeverity
    var arrivalState: SavedRouteArrivalState?
    var arrivalDebugInfo: SavedRouteArrivalDebugInfo?

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

                if let arrivalState {
                    arrivalSummaryView(for: arrivalState)
                }

                #if DEBUG
                if let arrivalDebugInfo {
                    arrivalDebugView(for: arrivalDebugInfo)
                }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)

            Spacer(minLength: 8)
        }
        .appCardStyle(padding: 15)
        .animation(AppDesign.subtleAnimation, value: severity.rawValue)
        .animation(AppDesign.subtleAnimation, value: arrivalState)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private func arrivalSummaryView(for arrivalState: SavedRouteArrivalState) -> some View {
        HStack(spacing: 6) {
            if arrivalState == .loading {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: arrivalIconName(for: arrivalState))
                    .font(.system(size: 11, weight: .semibold))
                    .accessibilityHidden(true)
            }

            Text(arrivalState.displayText)
                .font(.caption.weight(.semibold))
                .foregroundStyle(arrivalColor(for: arrivalState))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(arrivalColor(for: arrivalState).opacity(arrivalState == .arrival(minutes: 0) ? 0.12 : 0.08))
        .clipShape(Capsule())
        .accessibilityLabel(arrivalState.accessibilityText)
    }

    #if DEBUG
    private func arrivalDebugView(for debugInfo: SavedRouteArrivalDebugInfo) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("DEBUG arrival preview")
                .font(.caption2.weight(.bold))

            Text(debugInfo.selectedStopText)
                .font(.caption2)

            Text(debugInfo.busTimePredictionText)
                .font(.caption2)
        }
        .foregroundStyle(.secondary)
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityHidden(true)
    }
    #endif

    private var accessibilityLabel: String {
        if let arrivalState {
            return "\(route.displayName), \(severity.rawValue), \(arrivalState.accessibilityText)"
        }

        return "\(route.displayName), \(severity.rawValue)"
    }

    private func arrivalIconName(for arrivalState: SavedRouteArrivalState) -> String {
        switch arrivalState {
        case .loading:
            return "clock"
        case .unavailable:
            return "clock.badge.exclamationmark"
        case .arrival:
            return "clock.fill"
        }
    }

    private func arrivalColor(for arrivalState: SavedRouteArrivalState) -> Color {
        switch arrivalState {
        case .arrival:
            return .green
        case .loading, .unavailable:
            return .secondary
        }
    }
}

#if DEBUG
private extension SavedRouteArrivalDebugInfo {
    var selectedStopText: String {
        if let selectedStopName,
           let selectedStopID,
           let selectedStopDistanceInMeters {
            return "Selected stop: \(selectedStopName) (\(selectedStopID)) - \(Self.formattedDistance(selectedStopDistanceInMeters))"
        }

        if let nearestSearchedStopName,
           let nearestSearchedStopID,
           let nearestSearchedStopDistanceInMeters {
            return "Selected stop: none; nearest searched: \(nearestSearchedStopName) (\(nearestSearchedStopID)) - \(Self.formattedDistance(nearestSearchedStopDistanceInMeters))"
        }

        return "Selected stop: none"
    }

    var busTimePredictionText: String {
        let returnedPredictions = didBusTimeReturnPredictionsForSelectedStop ? "yes" : "no"
        return "BusTime returned predictions: \(returnedPredictions)"
    }

    static func formattedDistance(_ meters: Double) -> String {
        if meters >= 1_000 {
            return String(format: "%.1f km", meters / 1_000)
        }

        return "\(Int(meters.rounded())) m"
    }
}
#endif
