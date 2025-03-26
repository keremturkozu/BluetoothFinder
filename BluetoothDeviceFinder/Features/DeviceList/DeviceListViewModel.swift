import Foundation
import SwiftUI
import Combine
import CoreLocation

class DeviceListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var devices: [Device] = []
    @Published var isScanning = false
    @Published var isBluetoothEnabled = false
    @Published var isLocationAuthorized = false
    @Published var selectedDevice: Device?
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var deviceManager: DeviceManager?
    private var cancellables = Set<AnyCancellable>()
    private var sortMethod: SortMethod = .name
    
    // MARK: - Initialization
    init() {
        // Her 1 saniyede bir cihaz listesini güncelle
        setupPeriodicUpdates()
    }
    
    // MARK: - Dependency Injection
    func injectDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        bindToDeviceManager()
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard let deviceManager = deviceManager else { return }
        deviceManager.startScanning()
    }
    
    func stopScanning() {
        guard let deviceManager = deviceManager else { return }
        deviceManager.stopScanning()
    }
    
    func refreshDevices() {
        guard let deviceManager = deviceManager else { return }
        
        // Short scan to refresh device data
        deviceManager.startScanning()
        
        // Stop scanning after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
            guard let self = self else { return }
            if self.deviceManager?.isScanning == true {
                self.deviceManager?.stopScanning()
            }
        }
    }
    
    func selectDevice(_ device: Device) {
        selectedDevice = device
    }
    
    func toggleConnection(for device: Device) {
        guard let deviceManager = deviceManager else { return }
        
        if device.isConnected {
            deviceManager.disconnect(from: device)
        } else {
            deviceManager.connect(to: device)
        }
    }
    
    func saveDevice(_ device: Device) {
        guard let deviceManager = deviceManager else { return }
        deviceManager.saveDevice(device)
    }
    
    func forgetDevice(_ device: Device) {
        guard let deviceManager = deviceManager else { return }
        deviceManager.forgetDevice(device)
    }
    
    func toggleSaveDevice(_ device: Device) {
        guard let deviceManager = deviceManager else { return }
        deviceManager.toggleSaveDevice(device)
    }
    
    func deleteDevices(at offsets: IndexSet) {
        guard let deviceManager = deviceManager else { return }
        
        let devicesToDelete = offsets.map { devices[$0] }
        for device in devicesToDelete {
            deviceManager.removeDevice(device)
        }
    }
    
    // MARK: - Sorting Methods
    func sortByName() {
        sortMethod = .name
        sortDevices()
    }
    
    func sortBySignalStrength() {
        sortMethod = .signal
        sortDevices()
    }
    
    func sortByLastSeen() {
        sortMethod = .lastSeen
        sortDevices()
    }
    
    // MARK: - Private Methods
    private func bindToDeviceManager() {
        guard let deviceManager = deviceManager else { return }
        
        deviceManager.$devices
            .sink { [weak self] devices in
                guard let self = self else { return }
                self.devices = devices
                self.sortDevices()
            }
            .store(in: &cancellables)
        
        deviceManager.$isScanning
            .assign(to: \.isScanning, on: self)
            .store(in: &cancellables)
        
        deviceManager.$errorMessage
            .assign(to: \.errorMessage, on: self)
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
    
    private func sortDevices() {
        switch sortMethod {
        case .name:
            devices.sort { $0.name < $1.name }
        case .signal:
            devices.sort { (device1, device2) -> Bool in
                // Default to the lowest possible RSSI value if nil
                let rssi1 = device1.rssi ?? -100
                let rssi2 = device2.rssi ?? -100
                return rssi1 > rssi2
            }
        case .lastSeen:
            devices.sort { $0.lastSeen > $1.lastSeen }
        case .batteryLevel:
            devices.sort { (device1, device2) -> Bool in
                // Devices with battery levels come first
                if let level1 = device1.batteryLevel, let level2 = device2.batteryLevel {
                    return level1 > level2
                } else if device1.batteryLevel != nil {
                    return true
                } else if device2.batteryLevel != nil {
                    return false
                } else {
                    return device1.name < device2.name
                }
            }
        }
    }
    
    private func setupPeriodicUpdates() {
        // 1 saniyede bir cihaz mesafe ve sinyal güçlerini yenile
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isScanning else { return }
            
            // RSSI ve mesafe değerlerini yenile
            self.refreshRSSIValues()
        }
    }
    
    private func refreshRSSIValues() {
        // Cihazların RSSI değerlerini güncelleyerek mesafe hesaplamalarını yeniler
        DispatchQueue.main.async {
            // Sadece görünüm değişikliği olarak algılanması için publisher'a yeni değer göndermek yeterli
            // objectWillChange, view'ın refresh olmasını sağlar
            self.objectWillChange.send()
        }
    }
}

// MARK: - Helper Enums
enum SortMethod {
    case name
    case signal
    case lastSeen
    case batteryLevel
} 