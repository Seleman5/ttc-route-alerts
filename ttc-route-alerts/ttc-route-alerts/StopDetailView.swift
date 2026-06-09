//
//  StopDetailView.swift
//  ttc-route-alerts
//

import SwiftUI

struct StopDetailArrivalLoadResult: Equatable {
    let arrivals: [StopArrival]
    let dataSource: StopArrivalSource?
    let dataSourceMessage: String?
    let fallbackSectionTitle: String?
    let scheduleError: TTCStaticScheduleError?
}

struct StopDetailArrivalLoader {
    static let liveMessage = "Showing live TTC predictions"
    static let scheduledFallbackMessage = "Showing scheduled fallback times"
    static let noLivePredictionsMessage = "No live predictions available for this stop."
    static let scheduledFallbackSectionTitle = "Scheduled fallback"

    var fetchBusTimePredictions: ([String], TTCTripRouteData, Date, Int) async throws -> [StopArrival]
    var fetchLiveUpdates: () async throws -> [TTCLiveStopTimeUpdate]
    var usesSequenceFallback: Bool
    var fetchServedRouteIDs: (String) async -> Result<Set<String>, TTCStaticScheduleError>
    var fetchStopTimeSequenceKeys: (String) async -> Result<Set<String>, TTCStaticScheduleError>
    var fetchScheduledArrivals: (String) async -> Result<[StopArrival], TTCStaticScheduleError>

    init(
        fetchBusTimePredictions: @escaping ([String], TTCTripRouteData, Date, Int) async throws -> [StopArrival] = { stopIDs, tripRouteData, now, limit in
            try await TTCBusTimePredictionService().fetchPredictions(
                for: stopIDs,
                routesByID: tripRouteData.routesByID,
                now: now,
                limit: limit
            )
        },
        fetchLiveUpdates: @escaping () async throws -> [TTCLiveStopTimeUpdate] = {
            try await TTCTripUpdatesService().fetchTripUpdatesFeed()
        },
        usesSequenceFallback: Bool = false,
        fetchServedRouteIDs: @escaping (String) async -> Result<Set<String>, TTCStaticScheduleError> = { stopID in
            await Task.detached {
                TTCStaticScheduleStore.routeIDsServingStop(for: stopID)
            }.value
        },
        fetchStopTimeSequenceKeys: @escaping (String) async -> Result<Set<String>, TTCStaticScheduleError> = { stopID in
            await Task.detached {
                TTCStaticScheduleStore.stopTimeSequenceKeys(for: stopID)
            }.value
        },
        fetchScheduledArrivals: @escaping (String) async -> Result<[StopArrival], TTCStaticScheduleError> = { stopID in
            await Task.detached {
                TTCStaticScheduleStore.upcomingArrivals(for: stopID)
            }.value
        }
    ) {
        self.fetchBusTimePredictions = fetchBusTimePredictions
        self.fetchLiveUpdates = fetchLiveUpdates
        self.usesSequenceFallback = usesSequenceFallback
        self.fetchServedRouteIDs = fetchServedRouteIDs
        self.fetchStopTimeSequenceKeys = fetchStopTimeSequenceKeys
        self.fetchScheduledArrivals = fetchScheduledArrivals
    }

    func loadArrivals(
        for stopID: String,
        matchingStopIDs: [String],
        tripRouteData: TTCTripRouteData,
        now: Date = Date(),
        limit: Int = 10
    ) async -> StopDetailArrivalLoadResult {
        do {
            let busTimeArrivals = try await fetchBusTimePredictions(
                matchingStopIDs,
                tripRouteData,
                now,
                limit
            )

            if !busTimeArrivals.isEmpty {
                return StopDetailArrivalLoadResult(
                    arrivals: busTimeArrivals,
                    dataSource: .live,
                    dataSourceMessage: Self.liveMessage,
                    fallbackSectionTitle: nil,
                    scheduleError: nil
                )
            }
        } catch {
        }

        async let servedRouteIDsResult = fetchServedRouteIDs(stopID)

        do {
            let liveUpdates = try await fetchLiveUpdates()
            let servedRouteIDs = routeValidationIDs(from: await servedRouteIDsResult)
            let matchingLiveUpdates = TTCTripUpdatesService.matchingLiveUpdates(
                from: liveUpdates,
                stopID: stopID,
                alternateStopIDs: matchingStopIDs.filter { $0 != stopID }
            )
            let liveArrivals = TTCTripUpdatesService.stopArrivals(
                from: matchingLiveUpdates,
                stopID: stopID,
                alternateStopIDs: matchingStopIDs.filter { $0 != stopID },
                servedRouteIDs: servedRouteIDs,
                tripsByID: tripRouteData.tripsByID,
                routesByID: tripRouteData.routesByID,
                now: now,
                limit: limit
            )

            if !liveArrivals.isEmpty {
                return StopDetailArrivalLoadResult(
                    arrivals: liveArrivals,
                    dataSource: .live,
                    dataSourceMessage: Self.liveMessage,
                    fallbackSectionTitle: nil,
                    scheduleError: nil
                )
            }

            if usesSequenceFallback {
                let sequenceKeysResult = await fetchStopTimeSequenceKeys(stopID)
                let sequenceKeys = (try? sequenceKeysResult.get()) ?? []
                let sequenceMatchedLiveArrivals = TTCTripUpdatesService.stopArrivals(
                    from: liveUpdates,
                    stopID: stopID,
                    alternateStopIDs: matchingStopIDs.filter { $0 != stopID },
                    stopTimeSequenceKeys: sequenceKeys,
                    servedRouteIDs: servedRouteIDs,
                    tripsByID: tripRouteData.tripsByID,
                    routesByID: tripRouteData.routesByID,
                    now: now,
                    limit: limit
                )

                if !sequenceMatchedLiveArrivals.isEmpty {
                    return StopDetailArrivalLoadResult(
                        arrivals: sequenceMatchedLiveArrivals,
                        dataSource: .live,
                        dataSourceMessage: Self.liveMessage,
                        fallbackSectionTitle: nil,
                        scheduleError: nil
                    )
                }
            }
        } catch {
            // If live TTC predictions cannot be loaded, the stop detail screen falls back to static GTFS.
            _ = await servedRouteIDsResult
        }

        let scheduledResult = await fetchScheduledArrivals(stopID)

        switch scheduledResult {
        case .success(let scheduledArrivals):
            return StopDetailArrivalLoadResult(
                arrivals: scheduledArrivals,
                dataSource: .scheduled,
                dataSourceMessage: Self.noLivePredictionsMessage,
                fallbackSectionTitle: scheduledArrivals.isEmpty ? nil : Self.scheduledFallbackSectionTitle,
                scheduleError: nil
            )
        case .failure(let scheduleError):
            return StopDetailArrivalLoadResult(
                arrivals: [],
                dataSource: nil,
                dataSourceMessage: nil,
                fallbackSectionTitle: nil,
                scheduleError: scheduleError
            )
        }
    }

    private func routeValidationIDs(from result: Result<Set<String>, TTCStaticScheduleError>) -> Set<String> {
        (try? result.get()) ?? []
    }
}

struct StopDetailView: View {
    let nearbyStop: NearbyStop
    let ttcRed: Color

    @State private var arrivals: [StopArrival] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var dataSource: StopArrivalSource?
    @State private var dataSourceMessage: String?
    @State private var fallbackSectionTitle: String?

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

            if !isLoading, errorMessage == nil, let dataSource, let dataSourceMessage {
                ArrivalSourceStatusView(source: dataSource, message: dataSourceMessage)
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
                if let fallbackSectionTitle {
                    Text(fallbackSectionTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityAddTraits(.isHeader)
                }

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
        dataSource = nil
        dataSourceMessage = nil
        fallbackSectionTitle = nil

        let stopID = nearbyStop.stop.stopID
        let tripRouteData = TTCStaticScheduleStore.bundledTripRouteData()
        let result = await arrivalLoader.loadArrivals(
            for: stopID,
            matchingStopIDs: nearbyStop.stop.matchingStopIDs,
            tripRouteData: tripRouteData
        )

        arrivals = result.arrivals
        dataSource = result.dataSource
        dataSourceMessage = result.dataSourceMessage
        fallbackSectionTitle = result.fallbackSectionTitle

        if let scheduleError = result.scheduleError {
            arrivals = []
            dataSource = nil
            fallbackSectionTitle = nil
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

private struct ArrivalSourceStatusView: View {
    let source: StopArrivalSource
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            ArrivalSourceDot(source: source, size: 10)

            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(sourceColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(sourceColor.opacity(source == .live ? 0.10 : 0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.smallRadius))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
    }

    private var sourceColor: Color {
        source == .live ? .green : .secondary
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

                arrivalSourceBadge
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
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: AppDesign.smallRadius)
                .fill(sourceColor.opacity(arrival.source == .live ? 0.75 : 0.30))
                .frame(width: 3)
                .padding(.vertical, 10)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
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

    private var arrivalSourceBadge: some View {
        HStack(spacing: 6) {
            ArrivalSourceDot(source: arrival.source, size: 8)

            Text(sourceLabel)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(sourceColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(sourceColor.opacity(arrival.source == .live ? 0.14 : 0.08))
        .clipShape(Capsule())
        .accessibilityLabel(sourceLabel)
    }

    private var sourceColor: Color {
        arrival.source == .live ? .green : .secondary
    }

    private var sourceLabel: String {
        arrival.source == .live ? "Live prediction" : "Scheduled fallback"
    }

    private var accessibilityText: String {
        let headsignText = arrival.headsign.map { ", \($0)" } ?? ""
        return "\(sourceLabel), route \(arrival.routeNumber), \(arrival.routeName)\(headsignText), \(relativeArrivalText(for: arrival)), \(clockTimeText(for: arrival))"
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

private struct ArrivalSourceDot: View {
    let source: StopArrivalSource
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(sourceColor.opacity(source == .live ? 0.18 : 0.10))
                .frame(width: size + 8, height: size + 8)

            Circle()
                .fill(sourceColor)
                .frame(width: size, height: size)
        }
        .accessibilityHidden(true)
    }

    private var sourceColor: Color {
        source == .live ? .green : .secondary
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
