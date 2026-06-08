//
//  NearbyLocationManager.swift
//  ttc-route-alerts
//

import Combine
import CoreLocation
import Foundation

final class NearbyLocationManager: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var locationErrorMessage: String?
    @Published private(set) var isRequestingLocation = false

    private let locationManager = CLLocationManager()

    override init() {
        authorizationStatus = locationManager.authorizationStatus
        super.init()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestPermissionOrLocation() {
        locationErrorMessage = nil

        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            requestCurrentLocation()
        case .denied, .restricted:
            locationErrorMessage = "Location access is turned off for this app."
        @unknown default:
            locationErrorMessage = "Location access is unavailable right now."
        }
    }

    func requestCurrentLocation() {
        guard isAuthorized else {
            requestPermissionOrLocation()
            return
        }

        isRequestingLocation = true
        locationErrorMessage = nil
        locationManager.requestLocation()
    }
}

extension NearbyLocationManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async {
            self.authorizationStatus = manager.authorizationStatus

            if self.isAuthorized {
                self.requestCurrentLocation()
            } else if self.isDenied {
                self.isRequestingLocation = false
                self.locationErrorMessage = "Location access is turned off for this app."
            }
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        DispatchQueue.main.async {
            self.currentLocation = locations.last
            self.isRequestingLocation = false
            self.locationErrorMessage = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isRequestingLocation = false
            self.locationErrorMessage = "Couldn't find your location. Please try again."
        }
    }
}
