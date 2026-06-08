//
//  TTCStop.swift
//  ttc-route-alerts
//

import CoreLocation
import Foundation

struct TTCStop: Identifiable, Equatable {
    let stopID: String
    let stopName: String
    let latitude: Double
    let longitude: Double

    var id: String {
        stopID
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
