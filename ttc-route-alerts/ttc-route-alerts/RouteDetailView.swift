//
//  RouteDetailView.swift
//  ttc-route-alerts
//

import CoreLocation
import SwiftUI

struct RouteDetailView: View {
    let route: TTCAlertRoute
    let severity: AlertSeverity
    let alerts: [TTCAlert]
    let lastUpdatedText: String
    let ttcRed: Color
    let appBackground: Color
    @ObservedObject var locationManager: NearbyLocationManager
    var cachedArrivalDetail: SavedRouteArrivalDetail?

    @State private var arrivalDetail: SavedRouteArrivalDetail?
    @State private var isLoadingArrival = false

    private let savedRouteArrivalService = SavedRouteArrivalService()

    var routeAccentColor: Color {
        AppDesign.routeAccentColor(for: route.routeType)
    }

    var body: some View {
        ZStack {
            appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    detailHeader
                    if routeSupportsLiveArrival {
                        nextArrivalSection
                    }
                    alertsSection
                }
                .padding(.horizontal, AppDesign.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(route.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadArrivalIfNeeded()
        }
        .onReceive(locationManager.$currentLocation) { currentLocation in
            guard routeSupportsLiveArrival,
                  currentLocation != nil,
                  displayedArrivalDetail == nil else {
                return
            }

            Task {
                await loadArrivalIfNeeded()
            }
        }
    }

    var detailHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                RoundedRectangle(cornerRadius: AppDesign.iconRadius)
                    .fill(AppDesign.routeAccentBackground(for: route.routeType))
                    .frame(width: 52, height: 52)
                    .overlay {
                        Image(systemName: AppDesign.routeIconName(for: route.routeType))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(routeAccentColor)
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Text(route.displayName)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .lineLimit(3)
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    StatusBadgeView(severity: severity)
                }
                .layoutPriority(1)

                Spacer(minLength: 0)
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(routeAccentColor)
                    .frame(width: 20, height: 20)
                    .background(routeAccentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 5))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Successful Update")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(lastUpdatedText)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                }

                Spacer(minLength: 0)
            }
        }
        .appCardStyle(padding: 20)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(route.displayName), \(severity.rawValue), last successful update \(lastUpdatedText)")
    }

    var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeaderView(
                title: "TTC Alerts",
                systemImage: "exclamationmark.bubble",
                tint: ttcRed,
                accessoryText: alerts.isEmpty ? nil : "\(alerts.count)"
            )

            if alerts.isEmpty {
                noAlertsView
            } else {
                ForEach(alerts, id: \.self) { alert in
                    AlertCardView(
                        alertText: alert.text,
                        severity: AlertSeverity.forAlertText(alert.text),
                        lastUpdatedText: lastUpdatedText
                    )
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var nextArrivalSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeaderView(
                title: "Next Arrival",
                systemImage: "clock.fill",
                tint: routeAccentColor
            )

            if shouldShowArrivalLoading {
                nextArrivalLoadingView
            } else if let arrivalDetail = displayedArrivalDetail,
                      case .arrival = arrivalDetail.state {
                nextArrivalCard(for: arrivalDetail)
            } else {
                noNearbyArrivalView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(AppDesign.subtleAnimation, value: isLoadingArrival)
        .animation(AppDesign.subtleAnimation, value: displayedArrivalDetail?.state)
    }

    var noAlertsView: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 4) {
                Text("No alerts for this route right now.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)

                Text("The latest saved TTC alert feed has no matching alerts for this route.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .appCardStyle(padding: 14, cornerRadius: AppDesign.smallRadius)
        .accessibilityElement(children: .combine)
    }

    var nextArrivalLoadingView: some View {
        HStack(alignment: .center, spacing: 12) {
            ProgressView()
                .controlSize(.small)
                .accessibilityHidden(true)

            Text("Checking nearby live arrivals")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)
        }
        .appCardStyle(padding: 14, cornerRadius: AppDesign.smallRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Checking nearby live arrivals")
    }

    var noNearbyArrivalView: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "clock.badge.exclamationmark")
                .font(.title3)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text("No nearby live arrival found")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text("Live arrival previews use nearby bus and streetcar stops.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .appCardStyle(padding: 14, cornerRadius: AppDesign.smallRadius)
        .accessibilityElement(children: .combine)
    }

    func nextArrivalCard(for arrivalDetail: SavedRouteArrivalDetail) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "clock.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.green)
                .frame(width: 40, height: 40)
                .background(Color.green.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.iconRadius))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(arrivalText(for: arrivalDetail))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)

                if let stop = arrivalDetail.stop {
                    Text(stop.stopName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let distanceInMeters = arrivalDetail.distanceInMeters {
                    Text(distanceText(for: distanceInMeters))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 12)

            if arrivalDetail.source == .live {
                liveBadge
            }
        }
        .appCardStyle(padding: 14, cornerRadius: AppDesign.smallRadius)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(for: arrivalDetail))
    }

    var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.green)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Text("Live")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(Color.green.opacity(0.14))
        .clipShape(Capsule())
        .accessibilityLabel("Live prediction")
    }

    var displayedArrivalDetail: SavedRouteArrivalDetail? {
        arrivalDetail ?? cachedArrivalDetail
    }

    var shouldShowArrivalLoading: Bool {
        displayedArrivalDetail == nil
            && isLoadingArrival
            && !locationManager.isDenied
            && locationManager.locationErrorMessage == nil
    }

    var routeSupportsLiveArrival: Bool {
        route.routeType == .bus || route.routeType == .streetcar
    }

    @MainActor
    func loadArrivalIfNeeded() async {
        guard routeSupportsLiveArrival,
              displayedArrivalDetail == nil else {
            return
        }

        guard let currentLocation = locationManager.currentLocation else {
            if locationManager.isAuthorized {
                isLoadingArrival = true
                locationManager.requestCurrentLocation()
            } else {
                isLoadingArrival = false
            }
            return
        }

        isLoadingArrival = true

        let details = await savedRouteArrivalService.nextArrivalDetails(
            for: [route],
            currentLocation: currentLocation,
            stops: TTCStopsStore.bundledStops
        )

        if Task.isCancelled {
            return
        }

        arrivalDetail = details[route.id] ?? .unavailable
        isLoadingArrival = false
    }

    func arrivalText(for arrivalDetail: SavedRouteArrivalDetail) -> String {
        switch arrivalDetail.state {
        case .arrival(let minutes):
            if minutes == 0 {
                return "Arriving now"
            } else if minutes == 1 {
                return "Arrives in 1 min"
            } else {
                return "Arrives in \(minutes) min"
            }
        case .loading:
            return "Checking arrivals"
        case .unavailable:
            return "No nearby live arrival found"
        }
    }

    func distanceText(for distanceInMeters: CLLocationDistance) -> String {
        if distanceInMeters >= 1_000 {
            return String(format: "%.1f km away", distanceInMeters / 1_000)
        }

        return "\(Int(distanceInMeters.rounded())) m away"
    }

    func accessibilityText(for arrivalDetail: SavedRouteArrivalDetail) -> String {
        let stopText = arrivalDetail.stop.map { ", stop \($0.stopName)" } ?? ""
        let distanceDescription = arrivalDetail.distanceInMeters.map { ", \(distanceText(for: $0))" } ?? ""
        let sourceText = arrivalDetail.source == .live ? ", live prediction" : ""
        return "\(arrivalText(for: arrivalDetail))\(stopText)\(distanceDescription)\(sourceText)"
    }
}
