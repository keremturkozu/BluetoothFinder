import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    
    @Published var currentLocation: CLLocation?
    @Published var lastUpdated: Date?
    @Published var authorizationStatus: CLAuthorizationStatus
    @Published var errorMessage: String?
    
    private var locationPublisherSubject = PassthroughSubject<CLLocation, Never>()
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        return locationPublisherSubject.eraseToAnyPublisher()
    }
    
    private var locationUpdateTimer: Timer?
    private let locationUpdateInterval: TimeInterval = 30 // Update location every 30 seconds
    
    // MARK: - Initialization
    override init() {
        self.authorizationStatus = .notDetermined
        
        super.init()
        
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.activityType = .other
        locationManager.distanceFilter = 10 // Minimum distance in meters before triggering location update
        
        // Initialize with the current authorization status
        self.authorizationStatus = locationManager.authorizationStatus
        
        // Set default location based on user's country if possible
        if let countryCode = Locale.current.regionCode,
           let coordinates = getDefaultCoordinatesForCountry(countryCode) {
            let defaultLocation = CLLocation(
                latitude: coordinates.0,
                longitude: coordinates.1
            )
            currentLocation = defaultLocation
            locationPublisherSubject.send(defaultLocation)
        }
    }
    
    // MARK: - Public Methods
    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        guard CLLocationManager.locationServicesEnabled() else {
            errorMessage = "Location services are disabled"
            return
        }
        
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            // Try to get a quick location first
            locationManager.requestLocation()
            locationManager.startUpdatingLocation()
            startLocationUpdateTimer()
            print("Started updating location")
        case .notDetermined:
            requestAuthorization()
        case .denied, .restricted:
            errorMessage = "Location access denied"
        @unknown default:
            errorMessage = "Unknown authorization status"
        }
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        stopLocationUpdateTimer()
        print("Stopped updating location")
    }
    
    func requestSingleLocationUpdate() {
        if locationManager.authorizationStatus == .authorizedWhenInUse ||
           locationManager.authorizationStatus == .authorizedAlways {
            locationManager.requestLocation()
        } else {
            requestAuthorization()
        }
    }
    
    // MARK: - Private Methods
    private func startLocationUpdateTimer() {
        stopLocationUpdateTimer()
        
        locationUpdateTimer = Timer.scheduledTimer(withTimeInterval: locationUpdateInterval, repeats: true) { [weak self] _ in
            self?.requestSingleLocationUpdate()
        }
    }
    
    private func stopLocationUpdateTimer() {
        locationUpdateTimer?.invalidate()
        locationUpdateTimer = nil
    }
    
    private func getDefaultCoordinatesForCountry(_ countryCode: String) -> (Double, Double)? {
        // Default coordinates based on country code
        let coordinates: [String: (Double, Double)] = [
            "US": (37.0902, -95.7129),    // United States
            "GB": (55.3781, -3.4360),     // United Kingdom
            "TR": (38.9637, 35.2433),     // Turkey
            "DE": (51.1657, 10.4515),     // Germany
            "FR": (46.2276, 2.2137),      // France
            "IT": (41.8719, 12.5674),     // Italy
            "ES": (40.4637, -3.7492),     // Spain
            "JP": (36.2048, 138.2529),    // Japan
            "CN": (35.8617, 104.1954),    // China
            "IN": (20.5937, 78.9629),     // India
            "BR": (-14.2350, -51.9253),   // Brazil
            "AU": (-25.2744, 133.7751),   // Australia
            "RU": (61.5240, 105.3188),    // Russia
            "CA": (56.1304, -106.3468),   // Canada
            "MX": (23.6345, -102.5528)    // Mexico
        ]
        
        return coordinates[countryCode]
    }
    
    // MARK: - Helper Methods
    func calculateDistance(to location: CLLocation) -> Double? {
        guard let currentLocation = currentLocation else { return nil }
        return currentLocation.distance(from: location)
    }
    
    func getFormattedAddress(for location: CLLocation, completion: @escaping (String?) -> Void) {
        let geocoder = CLGeocoder()
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            guard error == nil, let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            var addressComponents: [String] = []
            
            if let name = placemark.name {
                addressComponents.append(name)
            }
            
            if let thoroughfare = placemark.thoroughfare {
                addressComponents.append(thoroughfare)
            }
            
            if let locality = placemark.locality {
                addressComponents.append(locality)
            }
            
            if let administrativeArea = placemark.administrativeArea {
                addressComponents.append(administrativeArea)
            }
            
            if let postalCode = placemark.postalCode {
                addressComponents.append(postalCode)
            }
            
            if let country = placemark.country {
                addressComponents.append(country)
            }
            
            let address = addressComponents.joined(separator: ", ")
            completion(address)
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        case .notDetermined:
            // Wait for the user to make a choice
            break
        case .denied, .restricted:
            errorMessage = "Location access denied"
            stopUpdatingLocation()
        @unknown default:
            errorMessage = "Unknown authorization status"
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only update if the location is recent and accurate enough
        let howRecent = location.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 10 && location.horizontalAccuracy >= 0 && location.horizontalAccuracy < 100 else {
            return
        }
        
        currentLocation = location
        lastUpdated = Date()
        locationPublisherSubject.send(location)
        print("Location updated: \(location.coordinate.latitude), \(location.coordinate.longitude)")
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let clError = error as? CLError {
            switch clError.code {
            case .denied:
                errorMessage = "Location access denied"
            case .network:
                errorMessage = "Network error"
            default:
                errorMessage = "Location error: \(error.localizedDescription)"
            }
        } else {
            errorMessage = "Error updating location: \(error.localizedDescription)"
        }
        
        print("Location manager error: \(error.localizedDescription)")
        
        // If we get a location error, try with reduced accuracy
        if manager.desiredAccuracy == kCLLocationAccuracyBest {
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.requestLocation()
        }
    }
} 