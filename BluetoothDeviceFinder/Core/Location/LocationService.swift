import Foundation
import CoreLocation
import Combine

protocol LocationServiceProtocol {
    var currentLocation: CLLocation? { get }
    var locationPublisher: AnyPublisher<CLLocation, Never> { get }
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> { get }
    
    func requestLocationPermission()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

class LocationService: NSObject, LocationServiceProtocol, ObservableObject {
    // MARK: - Properties
    private let locationManager = CLLocationManager()
    
    @Published private(set) var currentLocation: CLLocation?
    private let locationSubject = PassthroughSubject<CLLocation, Never>()
    private let authorizationStatusSubject = PassthroughSubject<CLAuthorizationStatus, Never>()
    
    var locationPublisher: AnyPublisher<CLLocation, Never> {
        locationSubject.eraseToAnyPublisher()
    }
    
    var authorizationStatusPublisher: AnyPublisher<CLAuthorizationStatus, Never> {
        authorizationStatusSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupLocationManager()
    }
    
    // MARK: - Public Methods
    func requestLocationPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Private Methods
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 10.0 // Update after moving 10 meters
        authorizationStatusSubject.send(locationManager.authorizationStatus)
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatusSubject.send(manager.authorizationStatus)
        
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        default:
            stopUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Only accept locations that are recent and accurate enough
        let howRecent = location.timestamp.timeIntervalSinceNow
        guard abs(howRecent) < 15.0, location.horizontalAccuracy < 100.0 else { return }
        
        currentLocation = location
        locationSubject.send(location)
    }
} 