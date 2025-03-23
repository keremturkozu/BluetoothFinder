import Foundation
import Combine
import CoreLocation

class DeviceListViewModel: ObservableObject {
    // MARK: - Properties
    private var deviceManager: DeviceManager
    private var cancellables = Set<AnyCancellable>()
    
    @Published var devices: [Device] = []
    @Published var isScanning = false
    @Published var isBluetoothEnabled = false
    @Published var isLocationAuthorized = false
    @Published var errorMessage: String?
    
    // MARK: - Initialization
    init(deviceManager: DeviceManager? = nil) {
        self.deviceManager = deviceManager ?? DeviceManager()
        setupBindings()
    }
    
    // MARK: - Public Methods
    func injectDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        // Cancel existing subscriptions
        cancellables.removeAll()
        setupBindings()
    }
    
    func toggleScanning() {
        if isScanning {
            deviceManager.stopScanning()
        } else {
            deviceManager.startScanning()
        }
        isScanning.toggle()
    }
    
    func connect(to device: Device) {
        deviceManager.connect(to: device)
    }
    
    func disconnect(from device: Device) {
        deviceManager.disconnect(from: device)
    }
    
    func updateDeviceLocation(_ device: Device) {
        deviceManager.updateDeviceLocation(device)
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        deviceManager.$devices
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.devices = devices.sorted { $0.lastSeen > $1.lastSeen }
            }
            .store(in: &cancellables)
        
        deviceManager.$isBluetoothEnabled
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isEnabled in
                self?.isBluetoothEnabled = isEnabled
                if !isEnabled && self?.isScanning == true {
                    self?.isScanning = false
                    self?.errorMessage = "Bluetooth is turned off. Please enable Bluetooth to scan for devices."
                } else {
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
        
        deviceManager.$isLocationAuthorized
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthorized in
                self?.isLocationAuthorized = isAuthorized
                if !isAuthorized && self?.isScanning == true {
                    self?.isScanning = false
                    self?.errorMessage = "Location services are not authorized. Please allow location access to scan for devices."
                } else if self?.isBluetoothEnabled == true {
                    self?.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }
} 