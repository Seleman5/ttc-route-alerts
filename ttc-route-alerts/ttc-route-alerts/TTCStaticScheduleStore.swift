//
//  TTCStaticScheduleStore.swift
//  ttc-route-alerts
//

import Foundation

struct GTFSStopTime: Equatable {
    let tripID: String
    let arrivalTime: String
    let stopID: String
    let stopSequence: Int?
    let arrivalSeconds: Int

    init(
        tripID: String,
        arrivalTime: String,
        stopID: String,
        stopSequence: Int? = nil,
        arrivalSeconds: Int
    ) {
        self.tripID = tripID
        self.arrivalTime = arrivalTime
        self.stopID = stopID
        self.stopSequence = stopSequence
        self.arrivalSeconds = arrivalSeconds
    }
}

struct GTFSTrip: Equatable {
    let tripID: String
    let routeID: String
    let headsign: String?
}

enum StopArrivalSource: String, Equatable {
    case live = "Live"
    case scheduled = "Scheduled"
}

struct StopArrival: Identifiable, Equatable {
    let id: String
    let routeNumber: String
    let routeName: String
    let headsign: String?
    let arrivalTime: String
    let arrivalSeconds: Int
    let arrivalDate: Date?
    let source: StopArrivalSource
}

enum StopArrivalSelection {
    static func preferredArrivals(liveArrivals: [StopArrival], scheduledArrivals: [StopArrival]) -> [StopArrival] {
        liveArrivals.isEmpty ? scheduledArrivals : liveArrivals
    }
}

enum TTCStaticScheduleError: Error, Equatable {
    case missingFile(String)
}

struct TTCStaticScheduleData {
    let stopTimesByStopID: [String: [GTFSStopTime]]
    let tripsByID: [String: GTFSTrip]
    let routesByID: [String: SuggestedRoute]
}

struct TTCTripRouteData {
    let tripsByID: [String: GTFSTrip]
    let routesByID: [String: SuggestedRoute]
}

private struct StopTimeHeaderIndexes {
    let tripIDIndex: Int
    let arrivalTimeIndex: Int
    let stopIDIndex: Int
    let stopSequenceIndex: Int?
}

enum TTCStaticScheduleStore {
    static func upcomingArrivals(
        for stopID: String,
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 10
    ) -> Result<[StopArrival], TTCStaticScheduleError> {
        bundledSchedule(for: stopID).map { schedule in
            upcomingArrivals(
                for: stopID,
                in: schedule,
                currentSeconds: secondsSinceMidnight(for: now, calendar: calendar),
                limit: limit
            )
        }
    }

    static func upcomingArrivals(
        for stopID: String,
        in schedule: TTCStaticScheduleData,
        currentSeconds: Int,
        limit: Int = 10
    ) -> [StopArrival] {
        let stopTimes = schedule.stopTimesByStopID[stopID] ?? []

        return stopTimes
            .filter { stopTime in
                stopTime.arrivalSeconds >= currentSeconds
            }
            .sorted { firstStopTime, secondStopTime in
                firstStopTime.arrivalSeconds < secondStopTime.arrivalSeconds
            }
            .compactMap { stopTime in
                scheduledArrival(for: stopTime, schedule: schedule)
            }
            .deduplicatedNearIdenticalScheduledArrivals()
            .prefix(limit)
            .map { $0 }
    }

    static func parseStopTimes(from stopTimesText: String) -> [GTFSStopTime] {
        parseStopTimes(from: stopTimesText, matchingStopIDs: nil)
    }

    static func parseStopTimes(
        from stopTimesText: String,
        matchingStopIDs: Set<String>?
    ) -> [GTFSStopTime] {
        var stopTimes: [GTFSStopTime] = []
        var headerIndexes: StopTimeHeaderIndexes?

        stopTimesText.enumerateLines { line, _ in
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedLine.isEmpty else {
                return
            }

            if headerIndexes == nil {
                let headers = csvFields(in: trimmedLine).map { field in
                    field.trimmingCharacters(in: .whitespacesAndNewlines)
                }

                guard let tripIDIndex = headers.firstIndex(of: "trip_id"),
                      let arrivalTimeIndex = headers.firstIndex(of: "arrival_time"),
                      let stopIDIndex = headers.firstIndex(of: "stop_id") else {
                    return
                }

                headerIndexes = StopTimeHeaderIndexes(
                    tripIDIndex: tripIDIndex,
                    arrivalTimeIndex: arrivalTimeIndex,
                    stopIDIndex: stopIDIndex,
                    stopSequenceIndex: headers.firstIndex(of: "stop_sequence")
                )
                return
            }

            guard let headerIndexes else {
                return
            }

            let fields = csvFields(in: trimmedLine)

            guard fields.indices.contains(headerIndexes.tripIDIndex),
                  fields.indices.contains(headerIndexes.arrivalTimeIndex),
                  fields.indices.contains(headerIndexes.stopIDIndex) else {
                return
            }

            let tripID = fields[headerIndexes.tripIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let arrivalTime = fields[headerIndexes.arrivalTimeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let stopID = fields[headerIndexes.stopIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)

            if let matchingStopIDs, !matchingStopIDs.contains(stopID) {
                return
            }

            let stopSequence = headerIndexes.stopSequenceIndex.flatMap { index -> Int? in
                guard fields.indices.contains(index) else {
                    return nil
                }

                let sequenceText = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
                return Int(sequenceText)
            }

            guard !tripID.isEmpty,
                  !arrivalTime.isEmpty,
                  !stopID.isEmpty,
                  let arrivalSeconds = secondsSinceMidnight(in: arrivalTime) else {
                return
            }

            stopTimes.append(
                GTFSStopTime(
                    tripID: tripID,
                    arrivalTime: arrivalTime,
                    stopID: stopID,
                    stopSequence: stopSequence,
                    arrivalSeconds: arrivalSeconds
                )
            )
        }

        return stopTimes
    }

    static func parseTrips(from tripsText: String) -> [GTFSTrip] {
        let lines = nonEmptyLines(in: tripsText)

        guard let headerLine = lines.first else {
            return []
        }

        let headers = csvFields(in: headerLine).map { field in
            field.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let routeIDIndex = headers.firstIndex(of: "route_id"),
              let tripIDIndex = headers.firstIndex(of: "trip_id") else {
            return []
        }

        let headsignIndex = headers.firstIndex(of: "trip_headsign")

        return lines.dropFirst().compactMap { line in
            let fields = csvFields(in: line)

            guard fields.indices.contains(routeIDIndex),
                  fields.indices.contains(tripIDIndex) else {
                return nil
            }

            let routeID = fields[routeIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let tripID = fields[tripIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let headsign = headsignIndex.flatMap { index -> String? in
                guard fields.indices.contains(index) else {
                    return nil
                }

                let text = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
                return text.isEmpty ? nil : text
            }

            guard !routeID.isEmpty, !tripID.isEmpty else {
                return nil
            }

            return GTFSTrip(tripID: tripID, routeID: routeID, headsign: headsign)
        }
    }

    static func secondsSinceMidnight(in gtfsTime: String) -> Int? {
        let parts = gtfsTime.split(separator: ":")

        guard parts.count == 3,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              let seconds = Int(parts[2]),
              hours >= 0,
              minutes >= 0,
              minutes < 60,
              seconds >= 0,
              seconds < 60 else {
            return nil
        }

        return (hours * 60 * 60) + (minutes * 60) + seconds
    }

    static func secondsSinceMidnight(for date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return ((components.hour ?? 0) * 60 * 60)
            + ((components.minute ?? 0) * 60)
            + (components.second ?? 0)
    }

    static func bundledTripRouteData() -> TTCTripRouteData {
        bundledTripRouteDataCache
    }

    static func stopTimeSequenceKeys(for stopID: String) -> Result<Set<String>, TTCStaticScheduleError> {
        bundledSchedule(for: stopID).map { schedule in
            let stopTimes = schedule.stopTimesByStopID[stopID] ?? []
            return Set(stopTimes.compactMap(sequenceKey(for:)))
        }
    }

    private static let bundledTripRouteDataCache: TTCTripRouteData = {
        let trips = loadBundledTrips()
        let routes = RouteSuggestion.suggestedRoutes

        return tripRouteData(trips: trips, routes: routes)
    }()

    private static var bundledScheduleCache: [String: Result<TTCStaticScheduleData, TTCStaticScheduleError>] = [:]
    private static let bundledScheduleCacheQueue = DispatchQueue(label: "TTCStaticScheduleStore.bundledScheduleCache")

    private static func bundledSchedule(for stopID: String) -> Result<TTCStaticScheduleData, TTCStaticScheduleError> {
        if let cachedResult = bundledScheduleCacheQueue.sync(execute: { bundledScheduleCache[stopID] }) {
            return cachedResult
        }

        let result: Result<TTCStaticScheduleData, TTCStaticScheduleError>

        do {
            result = .success(try loadBundledSchedule(for: stopID))
        } catch let error as TTCStaticScheduleError {
            result = .failure(error)
        } catch {
            result = .failure(.missingFile("GTFS schedule files"))
        }

        bundledScheduleCacheQueue.sync {
            bundledScheduleCache[stopID] = result
        }

        return result
    }

    private static func loadBundledSchedule(for stopID: String) throws -> TTCStaticScheduleData {
        guard let stopTimesFileURL = Bundle.main.url(forResource: "stop_times", withExtension: "txt") else {
            throw TTCStaticScheduleError.missingFile("stop_times.txt")
        }

        let stopTimesText = try String(contentsOf: stopTimesFileURL, encoding: .utf8)
        let stopTimes = parseStopTimes(
            from: stopTimesText,
            matchingStopIDs: [stopID]
        )
        let tripRouteData = bundledTripRouteData()

        return TTCStaticScheduleData(
            stopTimesByStopID: Dictionary(grouping: stopTimes) { stopTime in
                stopTime.stopID
            },
            tripsByID: tripRouteData.tripsByID,
            routesByID: tripRouteData.routesByID
        )
    }

    private static func loadBundledTrips() -> [GTFSTrip] {
        guard let tripsFileURL = Bundle.main.url(forResource: "trips", withExtension: "txt"),
              let tripsText = try? String(contentsOf: tripsFileURL, encoding: .utf8) else {
            return []
        }

        return parseTrips(from: tripsText)
    }

    static func scheduleData(
        stopTimes: [GTFSStopTime],
        trips: [GTFSTrip],
        routes: [SuggestedRoute]
    ) -> TTCStaticScheduleData {
        let stopTimesByStopID = Dictionary(grouping: stopTimes) { stopTime in
            stopTime.stopID
        }

        var tripsByID: [String: GTFSTrip] = [:]
        for trip in trips {
            tripsByID[trip.tripID] = trip
        }

        var routesByID: [String: SuggestedRoute] = [:]
        for route in routes {
            if let routeID = route.routeID {
                routesByID[routeID] = route
            }
        }

        return TTCStaticScheduleData(
            stopTimesByStopID: stopTimesByStopID,
            tripsByID: tripsByID,
            routesByID: routesByID
        )
    }

    static func tripRouteData(
        trips: [GTFSTrip],
        routes: [SuggestedRoute]
    ) -> TTCTripRouteData {
        var tripsByID: [String: GTFSTrip] = [:]
        for trip in trips {
            tripsByID[trip.tripID] = trip
        }

        var routesByID: [String: SuggestedRoute] = [:]
        for route in routes {
            if let routeID = route.routeID {
                routesByID[routeID] = route
            }
        }

        return TTCTripRouteData(tripsByID: tripsByID, routesByID: routesByID)
    }

    private static func scheduledArrival(
        for stopTime: GTFSStopTime,
        schedule: TTCStaticScheduleData
    ) -> StopArrival? {
        guard let trip = schedule.tripsByID[stopTime.tripID],
              let route = schedule.routesByID[trip.routeID] else {
            return nil
        }

        return StopArrival(
            id: "\(stopTime.tripID)-\(stopTime.stopID)-\(stopTime.arrivalTime)",
            routeNumber: route.routeNumber,
            routeName: route.nickname,
            headsign: trip.headsign,
            arrivalTime: stopTime.arrivalTime,
            arrivalSeconds: stopTime.arrivalSeconds,
            arrivalDate: nil,
            source: .scheduled
        )
    }

    static func sequenceKey(for stopTime: GTFSStopTime) -> String? {
        guard let stopSequence = stopTime.stopSequence else {
            return nil
        }

        return sequenceKey(tripID: stopTime.tripID, stopSequence: stopSequence)
    }

    static func sequenceKey(tripID: String, stopSequence: Int) -> String {
        "\(tripID)|\(stopSequence)"
    }

    private static func nonEmptyLines(in text: String) -> [String] {
        text
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private static func csvFields(in line: String) -> [String] {
        var fields: [String] = []
        var currentField = ""
        var isInsideQuotes = false
        var index = line.startIndex

        while index < line.endIndex {
            let character = line[index]

            if character == "\"" {
                let nextIndex = line.index(after: index)

                if isInsideQuotes, nextIndex < line.endIndex, line[nextIndex] == "\"" {
                    currentField.append(character)
                    index = nextIndex
                } else {
                    isInsideQuotes.toggle()
                }
            } else if character == "," && !isInsideQuotes {
                fields.append(currentField)
                currentField = ""
            } else {
                currentField.append(character)
            }

            index = line.index(after: index)
        }

        fields.append(currentField)
        return fields
    }
}

private extension Array where Element == StopArrival {
    func deduplicatedNearIdenticalScheduledArrivals() -> [StopArrival] {
        var arrivalsByRouteAndDirection: [String: StopArrival] = [:]
        var deduplicatedArrivals: [StopArrival] = []

        for arrival in self {
            guard arrival.source == .scheduled else {
                deduplicatedArrivals.append(arrival)
                continue
            }

            let key = [
                arrival.routeNumber.lowercased(),
                arrival.headsign?.lowercased() ?? ""
            ].joined(separator: "|")

            if let previousArrival = arrivalsByRouteAndDirection[key],
               arrival.arrivalSeconds - previousArrival.arrivalSeconds < 180 {
                continue
            }

            arrivalsByRouteAndDirection[key] = arrival
            deduplicatedArrivals.append(arrival)
        }

        return deduplicatedArrivals
    }
}
