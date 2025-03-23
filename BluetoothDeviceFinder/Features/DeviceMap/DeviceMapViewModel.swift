import Foundation
import CoreLocation
import Combine
import MapKit

class DeviceMapViewModel: NSObject, ObservableObject {
    // MARK: - Properties
    private var deviceManager: DeviceManager
    private let locationManager = CLLocationManager()
    private var cancellables = Set<AnyCancellable>()
    
    @Published var region: MKCoordinateRegion?
    @Published var devices: [Device] = []
    @Published var isLoading = true
    @Published var isScanning = false
    
    // MARK: - Initialization
    override init() {
        self.deviceManager = DeviceManager()
        super.init()
        setupLocationManager()
        setupBindings()
    }
    
    init(deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        super.init()
        setupLocationManager()
        setupBindings()
    }
    
    // MARK: - Public Methods
    func injectDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        // Cancel existing subscriptions
        cancellables.removeAll()
        setupBindings()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    func startScanning() {
        deviceManager.startScanning()
        isScanning = true
    }
    
    func stopScanning() {
        deviceManager.stopScanning()
        isScanning = false
    }
    
    // MARK: - Private Methods
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
    }
    
    private func setupBindings() {
        deviceManager.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices
            }
            .store(in: &cancellables)
    }
    
    private func updateRegion(with location: CLLocation) {
        let region = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        self.region = region
        self.isLoading = false
    }
}

// MARK: - CLLocationManagerDelegate
extension DeviceMapViewModel: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        default:
            stopUpdatingLocation()
            isLoading = false
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        updateRegion(with: location)
    }
} 