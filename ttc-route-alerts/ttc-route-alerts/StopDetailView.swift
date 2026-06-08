//
//  StopDetailView.swift
//  ttc-route-alerts
//

import SwiftUI

struct StopDetailArrivalLoadResult: Equatable {
    let arrivals: [StopArrival]
    let dataSourceMessage: String?
    let scheduleError: TTCStaticScheduleError?
}

struct StopDetailArrivalLoader {
    static let liveMessage = "Live predictions updated just now"
    static let scheduledFallbackMessage = "Live predictions unavailable. Showing scheduled times."

    var fetchLiveUpdates: () async throws -> [TTCLiveStopTimeUpdate]
    var fetchScheduledArrivals: (String) async -> Result<[StopArrival], TTCStaticScheduleError>

    init(
        fetchLiveUpdates: @escaping () async throws -> [TTCLiveStopTimeUpdate] = {
            try await TTCTripUpdatesService().fetchTripUpdatesFeed()
        },
        fetchScheduledArrivals: @escaping (String) async -> Result<[StopArrival], TTCStaticScheduleError> = { stopID in
            await Task.detached {
                TTCStaticScheduleStore.upcomingArrivals(for: stopID)
            }.value
        }
    ) {
        self.fetchLiveUpdates = fetchLiveUpdates
        self.fetchScheduledArrivals = fetchScheduledArrivals
    }

    func loadArrivals(
        for stopID: String,
        tripRouteData: TTCTripRouteData,
        now: Date = Date(),
        limit: Int = 10
    ) async -> StopDetailArrivalLoadResult {
        do {
            let liveUpdates = try await fetchLiveUpdates()
            let liveArrivals = TTCTripUpdatesService.stopArrivals(
                from: liveUpdates,
                stopID: stopID,
                tripsByID: tripRouteData.tripsByID,
                routesByID: tripRouteData.routesByID,
                now: now,
                limit: limit
            )

            if !liveArrivals.isEmpty {
                return StopDetailArrivalLoadResult(
                    arrivals: liveArrivals,
                    dataSourceMessage: Self.liveMessage,
                    scheduleError: nil
                )
            }
        } catch {
            // If live TTC predictions cannot be loaded, the stop detail screen falls back to static GTFS.
        }

        let scheduledResult = await fetchScheduledArrivals(stopID)

        switch scheduledResult {
        case .success(let scheduledArrivals):
            return StopDetailArrivalLoadResult(
                arrivals: scheduledArrivals,
                dataSourceMessage: Self.scheduledFallbackMessage,
                scheduleError: nil
            )
        case .failure(let scheduleError):
            return StopDetailArrivalLoadResult(
                arrivals: [],
                dataSourceMessage: nil,
                scheduleError: scheduleError
            )
        }
    }
}

struct StopDetailView: View {
    let nearbyStop: NearbyStop
    let ttcRed: Color

    @State private var arrivals: [StopArrival] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var dataSourceMessage: String?

    private let arrivalLoader = StopDetailArrivalLoader()

    var body: some View {
        ZStack {
            AppDesign.appBackground
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: AppDesign.sectionSpacing) {
                    stopHeader
                    arrivalsSection
                }
                .padding(.horizontal, AppDesign.screenHorizontalPadding)
                .padding(.top, 16)
                .padding(.bottom, 48)
            }
        }
        .navigationTitle("Stop Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task {
                        await loadArrivals()
                    }
                } label: {
                    ZStack {
                        Image(systemName: "arrow.clockwise")
                            .opacity(isLoading ? 0 : 1)

                        ProgressView()
                            .controlSize(.small)
                            .opacity(isLoading ? 1 : 0)
                    }
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
                }
                .font(.body.weight(.semibold))
                .disabled(isLoading)
                .accessibilityLabel(isLoading ? "Refreshing arrivals" : "Refresh arrivals")
                .accessibilityHint("Fetches fresh live TTC predictions for this stop.")
            }
        }
        .task {
            await loadArrivals()
        }
    }

    private var stopHeader: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(ttcRed)
                    .frame(width: 44, height: 44)
                    .background(ttcRed.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.iconRadius))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 5) {
                    Text(nearbyStop.stop.stopName)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Stop \(nearbyStop.stop.stopID)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 12)

                Text(distanceText(for: nearbyStop.distanceInMeters))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(ttcRed)
                    .monospacedDigit()
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(ttcRed.opacity(0.08))
                    .clipShape(Capsule())
                    .accessibilityLabel(distanceAccessibilityText(for: nearbyStop.distanceInMeters))
            }
        }
        .appCardStyle(padding: 16, cornerRadius: AppDesign.cardRadius)
    }

    @ViewBuilder
    private var arrivalsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HomeSectionHeaderView(
                title: "Arrivals",
                systemImage: "clock.fill",
                tint: ttcRed,
                accessoryText: arrivals.isEmpty ? nil : "\(arrivals.count)"
            )

            if !isLoading, errorMessage == nil, let dataSourceMessage {
                Text(dataSourceMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(AppDesign.insetBackground)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
            }

            if isLoading {
                StopDetailMessageView(
                    systemImage: "clock",
                    title: "Loading arrivals",
                    message: "Checking live arrivals for this stop.",
                    tint: ttcRed,
                    isLoading: true
                )
            } else if let errorMessage {
                StopDetailMessageView(
                    systemImage: "doc.text.magnifyingglass",
                    title: "Schedule unavailable",
                    message: errorMessage,
                    tint: .orange
                )
            } else if arrivals.isEmpty {
                StopDetailMessageView(
                    systemImage: "moon.zzz",
                    title: "No upcoming arrivals",
                    message: "There are no scheduled arrivals later today for this stop.",
                    tint: ttcRed
                )
            } else {
                ForEach(arrivals) { arrival in
                    ScheduledArrivalRow(arrival: arrival, ttcRed: ttcRed)
                }
            }
        }
    }

    @MainActor
    private func loadArrivals() async {
        isLoading = true
        errorMessage = nil
        dataSourceMessage = nil

        let stopID = nearbyStop.stop.stopID
        let tripRouteData = TTCStaticScheduleStore.bundledTripRouteData()
        let result = await arrivalLoader.loadArrivals(
            for: stopID,
            tripRouteData: tripRouteData
        )

        arrivals = result.arrivals
        dataSourceMessage = result.dataSourceMessage

        if let scheduleError = result.scheduleError {
            arrivals = []
            errorMessage = message(for: scheduleError)
        }

        isLoading = false
    }

    private func message(for error: TTCStaticScheduleError) -> String {
        switch error {
        case .missingFile(let fileName):
            return "Add \(fileName) to the app target to show scheduled arrivals."
        }
    }

    private func distanceText(for distance: Double) -> String {
        "\(Int(distance.rounded())) m"
    }

    private func distanceAccessibilityText(for distance: Double) -> String {
        "\(Int(distance.rounded())) meters away"
    }
}

private struct ScheduledArrivalRow: View {
    let arrival: StopArrival
    let ttcRed: Color

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            routeBadge

            VStack(alignment: .leading, spacing: 5) {
                Text(arrival.routeName)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                if let headsign = arrival.headsign {
                    Text(headsign)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Text(arrival.source.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(arrival.source == .live ? .green : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background((arrival.source == .live ? Color.green : Color.secondary).opacity(0.10))
                    .clipShape(Capsule())
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 3) {
                Text(relativeArrivalText(for: arrival))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(ttcRed)
                    .multilineTextAlignment(.trailing)

                Text(clockTimeText(for: arrival))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .accessibilityLabel("\(relativeArrivalText(for: arrival)), \(clockTimeText(for: arrival))")
        }
        .appCardStyle(padding: 14, cornerRadius: AppDesign.smallRadius)
        .accessibilityElement(children: .combine)
    }

    private var routeBadge: some View {
        Text(arrival.routeNumber)
            .font(.system(.headline, design: .rounded).weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: 44, height: 36)
            .background(ttcRed)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.iconRadius))
    }

    private func relativeArrivalText(for arrival: StopArrival) -> String {
        let secondsUntilArrival: TimeInterval

        if let arrivalDate = arrival.arrivalDate {
            secondsUntilArrival = arrivalDate.timeIntervalSinceNow
        } else {
            secondsUntilArrival = TimeInterval(arrival.arrivalSeconds - currentSecondsSinceMidnight())
        }

        let minutesUntilArrival = max(0, Int((secondsUntilArrival / 60).rounded()))

        if minutesUntilArrival == 0 {
            return "Arriving now"
        }

        if minutesUntilArrival == 1 {
            return "Arrives in 1 min"
        }

        return "Arrives in \(minutesUntilArrival) min"
    }

    private func clockTimeText(for arrival: StopArrival) -> String {
        if let arrivalDate = arrival.arrivalDate {
            return displayTime(for: arrivalDate)
        }

        return displayTime(for: arrival.arrivalTime)
    }

    private func displayTime(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func displayTime(for gtfsTime: String) -> String {
        guard let arrivalSeconds = TTCStaticScheduleStore.secondsSinceMidnight(in: gtfsTime) else {
            return gtfsTime
        }

        let secondsInDay = 24 * 60 * 60
        let normalizedSeconds = arrivalSeconds % secondsInDay
        let hours = normalizedSeconds / 3600
        let minutes = (normalizedSeconds % 3600) / 60
        let displayHour = hours % 12 == 0 ? 12 : hours % 12
        let suffix = hours < 12 ? "AM" : "PM"

        return String(format: "%d:%02d %@", displayHour, minutes, suffix)
    }

    private func currentSecondsSinceMidnight() -> Int {
        TTCStaticScheduleStore.secondsSinceMidnight(for: Date())
    }
}

private struct StopDetailMessageView: View {
    let systemImage: String
    let title: String
    let message: String
    let tint: Color
    var isLoading = false

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
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .appCardStyle(padding: 20)
    }
}
