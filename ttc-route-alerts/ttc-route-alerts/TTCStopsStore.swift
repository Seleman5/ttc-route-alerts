//
//  TTCStopsStore.swift
//  ttc-route-alerts
//

import CoreLocation
import Foundation

enum TTCStopsStore {
    static let bundledStops: [TTCStop] = {
        loadBundledStops()
    }()

    static func closestStops(
        to userLocation: CLLocation,
        from stops: [TTCStop] = bundledStops,
        limit: Int = 8
    ) -> [NearbyStop] {
        stops
            .map { stop in
                NearbyStop(
                    stop: stop,
                    distanceInMeters: userLocation.distance(from: stop.location)
                )
            }
            .sorted { firstStop, secondStop in
                firstStop.distanceInMeters < secondStop.distanceInMeters
            }
            .prefix(limit)
            .map { $0 }
    }

    static func loadBundledStops() -> [TTCStop] {
        guard let stopsFileURL = Bundle.main.url(forResource: "stops", withExtension: "txt") else {
            return []
        }

        do {
            let stopsText = try String(contentsOf: stopsFileURL, encoding: .utf8)
            return parseGTFSStops(from: stopsText)
        } catch {
            return []
        }
    }

    static func parseGTFSStops(from stopsText: String) -> [TTCStop] {
        let lines = stopsText
            .components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

        guard let headerLine = lines.first else {
            return []
        }

        let headers = csvFields(in: headerLine).map { field in
            field.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let stopIDIndex = headers.firstIndex(of: "stop_id"),
              let stopNameIndex = headers.firstIndex(of: "stop_name"),
              let stopLatitudeIndex = headers.firstIndex(of: "stop_lat"),
              let stopLongitudeIndex = headers.firstIndex(of: "stop_lon") else {
            return []
        }

        let stopCodeIndex = headers.firstIndex(of: "stop_code")
        var stops: [TTCStop] = []
        var seenStopIDs: Set<String> = []

        for line in lines.dropFirst() {
            let fields = csvFields(in: line)

            guard fields.indices.contains(stopIDIndex),
                  fields.indices.contains(stopNameIndex),
                  fields.indices.contains(stopLatitudeIndex),
                  fields.indices.contains(stopLongitudeIndex) else {
                continue
            }

            let stopID = fields[stopIDIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let stopCode = stopCodeIndex.flatMap { index -> String? in
                guard fields.indices.contains(index) else {
                    return nil
                }

                let code = fields[index].trimmingCharacters(in: .whitespacesAndNewlines)
                return code.isEmpty ? nil : code
            }
            let stopName = fields[stopNameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let stopLatitudeText = fields[stopLatitudeIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let stopLongitudeText = fields[stopLongitudeIndex].trimmingCharacters(in: .whitespacesAndNewlines)

            guard !stopID.isEmpty,
                  !stopName.isEmpty,
                  !seenStopIDs.contains(stopID),
                  let stopLatitude = Double(stopLatitudeText),
                  let stopLongitude = Double(stopLongitudeText) else {
                continue
            }

            stops.append(
                TTCStop(
                    stopID: stopID,
                    stopCode: stopCode,
                    stopName: stopName,
                    latitude: stopLatitude,
                    longitude: stopLongitude
                )
            )
            seenStopIDs.insert(stopID)
        }

        return stops
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
