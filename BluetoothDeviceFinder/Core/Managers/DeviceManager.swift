import Foundation
import CoreBluetooth
import Combine
import CoreLocation

class DeviceManager: ObservableObject {
    // MARK: - Properties
    @Published var devices: [Device] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var isBluetoothEnabled: Bool = false
    @Published var isLocationAuthorized: Bool = false
    
    private var deviceDictionary: [UUID: Device] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    let bluetoothService: BluetoothService
    let locationService: LocationService
    
    // MARK: - Initialization
    init() {
        self.bluetoothService = BluetoothService()
        self.locationService = LocationService()
        
        setupBluetoothService()
        setupLocationService()
        loadSavedDevices()
    }
    
    // MARK: - Public Methods
    func startScanning() {
        isScanning = true
        bluetoothService.startScanning()
    }
    
    func stopScanning() {
        isScanning = false
        bluetoothService.stopScanning()
    }
    
    func connect(to device: Device) {
        guard let peripheral = device.peripheral else {
            errorMessage = "Cannot connect: Device does not have a valid peripheral"
            return
        }
        
        bluetoothService.connect(to: peripheral)
    }
    
    func disconnect(from device: Device) {
        guard let peripheral = device.peripheral else {
            errorMessage = "Cannot disconnect: Device does not have a valid peripheral"
            return
        }
        
        bluetoothService.disconnect(from: peripheral)
    }
    
    func saveDevice(_ device: Device) {
        device.isSaved = true
        updateDevice(device)
        saveDevicesToDisk()
    }
    
    func forgetDevice(_ device: Device) {
        device.isSaved = false
        
        // If the device is connected, disconnect first
        if device.isConnected, let peripheral = device.peripheral {
            bluetoothService.disconnect(from: peripheral)
        }
        
        updateDevice(device)
        saveDevicesToDisk()
    }
    
    func toggleSaveDevice(_ device: Device) {
        if device.isSaved {
            forgetDevice(device)
        } else {
            saveDevice(device)
        }
    }
    
    func deviceFound(_ device: Device) {
        // Update last found timestamp
        device.lastSeen = Date()
        
        // Update the location if available
        if let currentLocation = locationService.currentLocation {
            device.updateLocation(currentLocation)
        }
        
        // Mark device as found and update
        // You could add additional functionality here like sending a notification
        updateDevice(device)
        saveDevicesToDisk()
    }
    
    func removeDevice(_ device: Device) {
        // First disconnect if needed
        if device.isConnected, let peripheral = device.peripheral {
            bluetoothService.disconnect(from: peripheral)
        }
        
        if let index = devices.firstIndex(of: device) {
            devices.remove(at: index)
        }
        
        deviceDictionary.removeValue(forKey: device.id)
        saveDevicesToDisk()
    }
    
    func updateDeviceLocation(_ device: Device) {
        guard let currentLocation = locationService.currentLocation else {
            errorMessage = "Cannot update location: Current location is unavailable"
            return
        }
        
        device.updateLocation(currentLocation)
        updateDevice(device)
        saveDevicesToDisk()
    }
    
    // MARK: - Private Methods
    private func setupBluetoothService() {
        bluetoothService.delegate = self
        
        // Update isBluetoothEnabled based on the current Bluetooth state
        isBluetoothEnabled = bluetoothService.isPoweredOn
    }
    
    private func setupLocationService() {
        // Setup binding to location service authorization status
        locationService.$authorizationStatus
            .sink { [weak self] status in
                self?.isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            }
            .store(in: &cancellables)
    }
    
    private func loadSavedDevices() {
        guard let savedDevicesData = UserDefaults.standard.data(forKey: "savedDevices") else {
            return
        }
        
        do {
            let savedDevices = try JSONDecoder().decode([Device].self, from: savedDevicesData)
            
            // Only include devices that were explicitly saved by the user
            for device in savedDevices where device.isSaved {
                deviceDictionary[device.id] = device
            }
            
            updateDevicesList()
        } catch {
            errorMessage = "Failed to load saved devices: \(error.localizedDescription)"
            print("Failed to load saved devices: \(error)")
        }
    }
    
    private func saveDevicesToDisk() {
        // Only save devices that have been explicitly saved by the user
        let devicesToSave = devices.filter { $0.isSaved }
        
        do {
            let encodedData = try JSONEncoder().encode(devicesToSave)
            UserDefaults.standard.set(encodedData, forKey: "savedDevices")
        } catch {
            errorMessage = "Failed to save devices: \(error.localizedDescription)"
            print("Failed to save devices: \(error)")
        }
    }
    
    private func updateDevicesList() {
        devices = Array(deviceDictionary.values).sorted { $0.name < $1.name }
    }
    
    public func updateDevice(_ device: Device) {
        deviceDictionary[device.id] = device
        updateDevicesList()
    }
    
    private func getDeviceType(from advertisementData: [String: Any]) -> DeviceType {
        // Simple implementation - in a real app, this would be more comprehensive
        if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
            let lowercaseName = localName.lowercased()
            
            if lowercaseName.contains("headphone") || lowercaseName.contains("airpod") {
                return .headphones
            } else if lowercaseName.contains("watch") {
                return .watch
            } else if lowercaseName.contains("keyboard") {
                return .keyboard
            } else if lowercaseName.contains("mouse") {
                return .mouse
            }
        }
        
        return .unknown
    }
}

// MARK: - BluetoothServiceDelegate
extension DeviceManager: BluetoothServiceDelegate {
    func didDiscoverDevice(peripheral: CBPeripheral, rssi: NSNumber, advertisementData: [String: Any]) {
        let deviceName = peripheral.name ?? "Unknown Device"
        let deviceType = getDeviceType(from: advertisementData)
        
        // Check if we already have this device in our dictionary
        if let existingDevice = deviceDictionary[peripheral.identifier] {
            existingDevice.update(with: peripheral, rssi: rssi.intValue, advertisementData: advertisementData)
            updateDevice(existingDevice)
        } else {
            // Create a new device
            let newDevice = Device(
                id: peripheral.identifier,
                peripheral: peripheral,
                name: deviceName,
                rssi: rssi.intValue,
                batteryLevel: nil,
                isConnected: peripheral.state == .connected,
                type: deviceType,
                advertisementData: advertisementData
            )
            
            // If location services are available, add the current location
            if let currentLocation = locationService.currentLocation {
                newDevice.updateLocation(currentLocation)
            }
            
            deviceDictionary[peripheral.identifier] = newDevice
            updateDevicesList()
        }
    }
    
    func didConnectToDevice(_ peripheral: CBPeripheral) {
        if let device = deviceDictionary[peripheral.identifier] {
            device.isConnected = true
            updateDevice(device)
            
            // Discover services to potentially get battery information
            bluetoothService.discoverServices(for: peripheral)
        }
    }
    
    func didDisconnectFromDevice(_ peripheral: CBPeripheral, error: Error?) {
        if let device = deviceDictionary[peripheral.identifier] {
            device.isConnected = false
            updateDevice(device)
        }
    }
    
    func didFailToConnect(_ peripheral: CBPeripheral, error: Error?) {
        if let device = deviceDictionary[peripheral.identifier] {
            device.isConnected = false
            updateDevice(device)
        }
        
        if let error = error {
            errorMessage = "Failed to connect: \(error.localizedDescription)"
        }
    }
    
    func didUpdateValueFor(characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        // Check for battery level characteristic
        if characteristic.uuid == CBUUID(string: "2A19") {
            if let data = characteristic.value, data.count > 0 {
                let batteryLevel = Int(data[0])
                
                if let device = deviceDictionary[peripheral.identifier] {
                    device.batteryLevel = batteryLevel
                    updateDevice(device)
                }
            }
        }
    }
} 