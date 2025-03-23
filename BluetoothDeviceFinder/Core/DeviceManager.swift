import Foundation
import CoreLocation
import Combine

class DeviceManager: ObservableObject {
    // MARK: - Properties
    private let bluetoothService: BluetoothServiceProtocol
    private let locationService: LocationServiceProtocol
    private var cancellables = Set<AnyCancellable>()
    
    @Published private(set) var devices: [Device] = []
    @Published private(set) var isBluetoothEnabled = false
    @Published private(set) var isLocationAuthorized = false
    
    // MARK: - Initialization
    init(
        bluetoothService: BluetoothServiceProtocol = BluetoothService(),
        locationService: LocationServiceProtocol = LocationService()
    ) {
        self.bluetoothService = bluetoothService
        self.locationService = locationService
        
        setupSubscriptions()
    }
    
    // MARK: - Public Methods
    func startScanning() {
        locationService.requestLocationPermission()
        locationService.startUpdatingLocation()
        bluetoothService.startScanning()
    }
    
    func stopScanning() {
        locationService.stopUpdatingLocation()
        bluetoothService.stopScanning()
    }
    
    func connect(to device: Device) {
        bluetoothService.connect(to: device)
    }
    
    func disconnect(from device: Device) {
        bluetoothService.disconnect(from: device)
    }
    
    func updateDeviceLocation(_ device: Device, location: CLLocation? = nil) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        var updatedDevice = devices[index]
        updatedDevice.location = location ?? locationService.currentLocation
        updatedDevice.lastSeen = Date()
        devices[index] = updatedDevice
    }
    
    // MARK: - Private Methods
    private func setupSubscriptions() {
        // Subscribe to Bluetooth state updates
        bluetoothService.statePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.isBluetoothEnabled = (state == .poweredOn)
            }
            .store(in: &cancellables)
        
        // Subscribe to device updates
        bluetoothService.devicesPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedDevices in
                guard let self = self else { return }
                self.devices = updatedDevices.map { device in
                    var updatedDevice = device
                    if let location = self.locationService.currentLocation {
                        updatedDevice.location = location
                    }
                    return updatedDevice
                }
            }
            .store(in: &cancellables)
        
        // Subscribe to location authorization updates
        locationService.authorizationStatusPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                self?.isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            }
            .store(in: &cancellables)
        
        // Update device locations when user location changes
        locationService.locationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] location in
                guard let self = self else { return }
                // Update locations of nearby connected devices
                for (index, device) in self.devices.enumerated() where device.isConnected {
                    var updatedDevice = device
                    updatedDevice.location = location
                    self.devices[index] = updatedDevice
                }
            }
            .store(in: &cancellables)
    }
} 