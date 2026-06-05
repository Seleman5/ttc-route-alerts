//
//  TTCStatusWidget.swift
//  TTCStatusWidget
//

import SwiftUI
import WidgetKit

private let appGroupIdentifier = "group.com.sully.ttc-route-alerts"
private let widgetSnapshotKey = "widgetRouteStatusSnapshot"

struct WidgetRouteStatus: Codable, Identifiable {
    let id: UUID
    let displayName: String
    let severity: String
}

struct WidgetStatusSnapshot: Codable {
    let routes: [WidgetRouteStatus]
    let lastUpdatedDate: Date?
}

struct TTCStatusEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetStatusSnapshot?
}

struct TTCStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> TTCStatusEntry {
        TTCStatusEntry(date: Date(), snapshot: Self.previewSnapshot)
    }

    func getSnapshot(in context: Context, completion: @escaping (TTCStatusEntry) -> Void) {
        completion(TTCStatusEntry(date: Date(), snapshot: loadSnapshot() ?? Self.previewSnapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TTCStatusEntry>) -> Void) {
        let entry = TTCStatusEntry(date: Date(), snapshot: loadSnapshot())
        let nextRefresh = Date().addingTimeInterval(15 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func loadSnapshot() -> WidgetStatusSnapshot? {
        guard let sharedDefaults = UserDefaults(suiteName: appGroupIdentifier),
              let savedData = sharedDefaults.data(forKey: widgetSnapshotKey) else {
            return nil
        }

        return try? JSONDecoder().decode(WidgetStatusSnapshot.self, from: savedData)
    }

    private static var previewSnapshot: WidgetStatusSnapshot {
        WidgetStatusSnapshot(
            routes: [
                WidgetRouteStatus(id: UUID(), displayName: "Subway Line 1", severity: "Normal"),
                WidgetRouteStatus(id: UUID(), displayName: "Bus 131", severity: "Minor Alert"),
                WidgetRouteStatus(id: UUID(), displayName: "Streetcar 501", severity: "Normal")
            ],
            lastUpdatedDate: Date()
        )
    }
}

struct TTCStatusWidgetView: View {
    let entry: TTCStatusEntry

    private let ttcRed = Color(red: 0.85, green: 0.06, blue: 0.10)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle()
                    .fill(ttcRed)
                    .frame(width: 18, height: 18)
                    .overlay {
                        Image(systemName: "tram.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                    }

                Text("TTC Route Alerts")
                    .font(.caption)
                    .fontWeight(.bold)
                    .lineLimit(1)
            }

            if routes.isEmpty {
                Spacer(minLength: 2)

                Text("Open the app to sync saved routes.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 2)
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    ForEach(routes) { route in
                        routeRow(route)
                    }
                }
            }

            Spacer(minLength: 0)

            Text(lastUpdatedText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .containerBackground(Color(.systemBackground), for: .widget)
    }

    private var routes: [WidgetRouteStatus] {
        Array((entry.snapshot?.routes ?? []).prefix(3))
    }

    private var lastUpdatedText: String {
        guard let lastUpdatedDate = entry.snapshot?.lastUpdatedDate else {
            return "Not updated yet"
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return "Updated \(formatter.localizedString(for: lastUpdatedDate, relativeTo: entry.date))"
    }

    private func routeRow(_ route: WidgetRouteStatus) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color(for: route.severity))
                .frame(width: 7, height: 7)

            Text(route.displayName)
                .font(.system(size: 11, weight: .semibold))
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(shortStatus(for: route.severity))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color(for: route.severity))
                .lineLimit(1)
        }
    }

    private func color(for severity: String) -> Color {
        switch severity {
        case "Major Alert":
            return .red
        case "Minor Alert":
            return .orange
        default:
            return .green
        }
    }

    private func shortStatus(for severity: String) -> String {
        switch severity {
        case "Major Alert":
            return "Major"
        case "Minor Alert":
            return "Alert"
        default:
            return "Normal"
        }
    }
}

@main
struct TTCStatusWidget: Widget {
    let kind = "TTCStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TTCStatusProvider()) { entry in
            TTCStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("TTC Route Alerts")
        .description("Shows the current status of your saved TTC routes.")
        .supportedFamilies([.systemSmall])
    }
}
