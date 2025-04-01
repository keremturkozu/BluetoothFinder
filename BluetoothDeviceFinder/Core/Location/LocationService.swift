import Foundation
import CoreLocation
import Combine
import os.log

class LocationService: NSObject, ObservableObject {
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((CLLocation?) -> Void)?
    private let logger = Logger(subsystem: "com.nachz.BluetoothDeviceFinder", category: "Location")
    
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var lastError: Error?
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        // Check initial authorization status
        authorizationStatus = locationManager.authorizationStatus
        
        // Start location updates if already authorized
        if authorizationStatus == .authorizedWhenInUse || self.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        }
    }
    
    // MARK: - Public Methods
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func getCurrentLocation() async -> CLLocation? {
        // If we already have a recent location (within last 5 minutes), return it
        if let location = currentLocation, Date().timeIntervalSince(location.timestamp) < 300 {
            return location
        }
        
        return await withCheckedContinuation { continuation in
            requestLocation { location in
                continuation.resume(returning: location)
            }
        }
    }
    
    private func requestLocation(completion: @escaping (CLLocation?) -> Void) {
        // Store completion handler
        locationCompletion = completion
        
        // Check authorization status
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            locationCompletion?(nil)
            locationCompletion = nil
        @unknown default:
            locationCompletion?(nil)
            locationCompletion = nil
        }
    }
    
    // Get distance between current location and a given location
    func getDistance(to location: CLLocation) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else {
            logger.error("Cannot calculate distance: Current location is unavailable")
            return nil
        }
        
        return currentLocation.distance(from: location)
    }
    
    // Format a distance value for display
    func formatDistance(_ distance: CLLocationDistance) -> String {
        if distance < 1000 {
            return String(format: "%.0f m", distance)
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        
        if manager.authorizationStatus == .authorizedWhenInUse || 
           manager.authorizationStatus == .authorizedAlways {
            locationManager.startUpdatingLocation()
        } else {
            locationManager.stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        currentLocation = location
        
        // If we have a completion handler, call it with the location
        if let completion = locationCompletion {
            completion(location)
            locationCompletion = nil
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error
        
        // If we have a completion handler, call it with nil location
        if let completion = locationCompletion {
            completion(nil)
            locationCompletion = nil
        }
    }
} 

