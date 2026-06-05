//
//  RouteDetailView.swift
//  ttc-route-alerts
//

import SwiftUI

struct RouteDetailView: View {
    let route: TTCAlertRoute
    let severity: AlertSeverity
    let alerts: [TTCAlert]
    let lastUpdatedText: String
    let ttcRed: Color
    let appBackground: Color

    var body: some View {
        ZStack {
            appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    detailHeader
                    alertsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 28)
            }
        }
        .navigationTitle(route.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }

    var detailHeader: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Circle()
                    .fill(ttcRed)
                    .frame(width: 56, height: 56)
                    .overlay {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 23, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                VStack(alignment: .leading, spacing: 10) {
                    Text(route.displayName)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    StatusBadgeView(severity: severity)
                }

                Spacer(minLength: 0)
            }

            Divider()

            HStack(spacing: 10) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(ttcRed)
                    .frame(width: 20, height: 20)
                    .background(ttcRed.opacity(0.07))
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 12, x: 0, y: 5)
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
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.04), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
    }
}
