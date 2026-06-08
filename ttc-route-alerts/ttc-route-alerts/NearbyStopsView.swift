//
//  NearbyStopsView.swift
//  ttc-route-alerts
//

import CoreLocation
import SwiftUI
import UIKit

struct NearbyStopsView: View {
    @StateObject private var locationManager = NearbyLocationManager()

    let ttcRed: Color

    private let stops = TTCStopsStore.bundledStops

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HomeSectionHeaderView(
                title: "Nearby Stops",
                systemImage: "location.fill",
                tint: ttcRed,
                accessoryText: stops.isEmpty ? nil : "\(stops.count)"
            )

            content
        }
        .onAppear {
            if locationManager.isAuthorized {
                locationManager.requestCurrentLocation()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if locationManager.isDenied {
            NearbyMessageView(
                systemImage: "location.slash",
                title: "Location access is off",
                message: "Turn on location access for this app to see the closest TTC stops.",
                tint: .orange,
                buttonTitle: "Open Settings",
                buttonSystemImage: "gearshape",
                buttonAction: openAppSettings
            )
        } else if stops.isEmpty {
            NearbyMessageView(
                systemImage: "doc.text.magnifyingglass",
                title: "stops.txt not found",
                message: "Add the TTC GTFS stops.txt file to the app target to show nearby stops.",
                tint: ttcRed
            )
        } else if !locationManager.isAuthorized {
            NearbyMessageView(
                systemImage: "location",
                title: "Use your location",
                message: "Allow location access to show the closest TTC stops.",
                tint: ttcRed,
                buttonTitle: "Allow Location",
                buttonSystemImage: "location.fill",
                buttonAction: locationManager.requestPermissionOrLocation
            )
        } else if let currentLocation = locationManager.currentLocation {
            nearbyStopsList(for: currentLocation)
        } else {
            NearbyMessageView(
                systemImage: "location.viewfinder",
                title: "Finding nearby stops",
                message: locationManager.locationErrorMessage ?? "Waiting for your current location.",
                tint: ttcRed,
                isLoading: locationManager.isRequestingLocation,
                buttonTitle: "Try Again",
                buttonSystemImage: "arrow.clockwise",
                buttonAction: locationManager.requestCurrentLocation
            )
        }
    }

    private func nearbyStopsList(for currentLocation: CLLocation) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let locationErrorMessage = locationManager.locationErrorMessage {
                Text(locationErrorMessage)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.orange.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
            }

            ForEach(TTCStopsStore.closestStops(to: currentLocation, from: stops)) { nearbyStop in
                NearbyStopRow(nearbyStop: nearbyStop, ttcRed: ttcRed)
            }

            Button {
                locationManager.requestCurrentLocation()
            } label: {
                Label("Refresh Location", systemImage: "arrow.clockwise")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(ttcRed)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
            .disabled(locationManager.isRequestingLocation)
            .accessibilityHint("Updates your current location and recalculates nearby TTC stops.")
        }
    }

    private func openAppSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }
}

private struct NearbyStopRow: View {
    let nearbyStop: NearbyStop
    let ttcRed: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(ttcRed)
                .frame(width: 36, height: 36)
                .background(ttcRed.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.iconRadius))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(nearbyStop.stop.stopName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(nearbyStop.stop.stopID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Text(distanceText(for: nearbyStop.distanceInMeters))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(ttcRed)
                .monospacedDigit()
                .accessibilityLabel(distanceAccessibilityText(for: nearbyStop.distanceInMeters))
        }
        .appCardStyle(padding: 14, cornerRadius: AppDesign.smallRadius)
        .accessibilityElement(children: .combine)
    }

    private func distanceText(for distance: CLLocationDistance) -> String {
        let roundedDistance = Int(distance.rounded())
        return "\(roundedDistance) m"
    }

    private func distanceAccessibilityText(for distance: CLLocationDistance) -> String {
        let roundedDistance = Int(distance.rounded())
        return "\(roundedDistance) meters away"
    }
}

private struct NearbyMessageView: View {
    let systemImage: String
    let title: String
    let message: String
    let tint: Color
    var isLoading = false
    var buttonTitle: String?
    var buttonSystemImage: String?
    var buttonAction: (() -> Void)?

    var body: some View {
        VStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: AppDesign.iconRadius)
                    .fill(tint.opacity(0.10))
                    .frame(width: 48, height: 48)

                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: systemImage)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(tint)
                }
            }
            .accessibilityHidden(true)

            Text(title)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if let buttonTitle, let buttonAction {
                Button(action: buttonAction) {
                    Label(buttonTitle, systemImage: buttonSystemImage ?? "arrow.right")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.white)
                .background(tint)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .appCardStyle(padding: 20)
    }
}
