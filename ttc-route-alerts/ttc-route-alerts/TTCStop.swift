//
//  TTCStop.swift
//  ttc-route-alerts
//

import CoreLocation
import Foundation

struct TTCStop: Identifiable, Equatable {
    let stopID: String
    let stopCode: String?
    let stopName: String
    let latitude: Double
    let longitude: Double

    init(
        stopID: String,
        stopCode: String? = nil,
        stopName: String,
        latitude: Double,
        longitude: Double
    ) {
        self.stopID = stopID
        self.stopCode = stopCode
        self.stopName = stopName
        self.latitude = latitude
        self.longitude = longitude
    }

    var id: String {
        stopID
    }

    var matchingStopIDs: [String] {
        var ids = [stopID]

        if let stopCode, !stopCode.isEmpty, stopCode != stopID {
            ids.append(stopCode)
        }

        return ids
    }

    var location: CLLocation {
        CLLocation(latitude: latitude, longitude: longitude)
    }
}

struct NearbyStop: Identifiable, Equatable {
    let stop: TTCStop
    let distanceInMeters: CLLocationDistance

    var id: String {
        stop.id
    }
}
