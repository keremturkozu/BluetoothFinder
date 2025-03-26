import Foundation
import CoreBluetooth
import Combine

protocol BluetoothServiceDelegate: AnyObject {
    func didDiscoverDevice(peripheral: CBPeripheral, rssi: NSNumber, advertisementData: [String: Any])
    func didConnectToDevice(_ peripheral: CBPeripheral)
    func didDisconnectFromDevice(_ peripheral: CBPeripheral, error: Error?)
    func didFailToConnect(_ peripheral: CBPeripheral, error: Error?)
    func didUpdateValueFor(characteristic: CBCharacteristic, peripheral: CBPeripheral)
    func bluetoothStateDidUpdate(isPoweredOn: Bool)
}

class BluetoothService: NSObject {
    // MARK: - Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    private var discoveredServices: [CBService] = []
    private var discoveredCharacteristics: [CBCharacteristic] = []
    
    // Known Service UUIDs
    private let batteryServiceUUID = CBUUID(string: "180F")
    private let batteryLevelCharacteristicUUID = CBUUID(string: "2A19")
    private let deviceInfoServiceUUID = CBUUID(string: "180A")
    private let audioServiceUUID = CBUUID(string: "1107") // Audio Remote Control Service
    private let audioPlayCharacteristicUUID = CBUUID(string: "1109") // Remote Control
    
    // Apple AirPods and other specific devices
    private let appleManufacturerID: UInt16 = 0x004C
    
    // Dictionary to track peripheral discovery attempts
    private var discoveryAttempts: [UUID: Int] = [:]
    private let maxDiscoveryAttempts = 3
    
    weak var delegate: BluetoothServiceDelegate?
    
    var isScanning: Bool {
        return centralManager.isScanning
    }
    
    var isPoweredOn: Bool {
        let state = centralManager.state
        let result = state == .poweredOn
        print("📱 BluetoothService.isPoweredOn: \(result) (state: \(state.rawValue))")
        return result
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        
        // Request "Always" authorization for background operation
        let options: [String: Any] = [
            CBCentralManagerOptionShowPowerAlertKey: true,
            CBCentralManagerOptionRestoreIdentifierKey: "com.bluetoothfinder.centralmanager"
        ]
        
        centralManager = CBCentralManager(delegate: self, queue: nil, options: options)
        
        print("BluetoothService initialized, CBCentralManager state: \(centralManager.state.rawValue)")
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not available. Current state: \(centralManager.state.rawValue)")
            
            // Provide more detailed debugging information
            switch centralManager.state {
            case .poweredOff:
                print("Bluetooth is powered OFF. Please enable Bluetooth in device settings.")
            case .unauthorized:
                print("Bluetooth permission denied. Please authorize Bluetooth in app settings.")
            case .unsupported:
                print("Bluetooth is not supported on this device.")
            case .resetting:
                print("Bluetooth is resetting.")
            case .unknown:
                print("Bluetooth state is unknown.")
            default:
                print("Bluetooth is unavailable. Please check device settings.")
            }
            
            // Notify delegate about Bluetooth state
            delegate?.bluetoothStateDidUpdate(isPoweredOn: false)
            return
        }
        
        // Common Bluetooth services for discovery
        let services: [CBUUID] = [
            CBUUID(string: "1800"), // Generic Access
            CBUUID(string: "180A"), // Device Information
            CBUUID(string: "180F"), // Battery Service
            CBUUID(string: "1812"), // HID
            CBUUID(string: "1107"), // Audio Remote Control
            CBUUID(string: "FE9F")  // Apple Nearby Service
        ]
        
        print("Starting Bluetooth scan for devices...")
        
        // First, scan for all devices with duplicates allowed for better discovery
        let scanOptions: [String: Any] = [
            CBCentralManagerScanOptionAllowDuplicatesKey: true
        ]
        
        centralManager.scanForPeripherals(withServices: nil, options: scanOptions)
        
        print("Scanning for ALL Bluetooth devices (wide scan)")
        
        // Set a timer to adjust scanning parameters after initial discovery
        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
            guard let self = self, self.centralManager.isScanning else { return }
            
            // Switch to more focused scanning after initial discovery
            self.centralManager.stopScan()
            print("Switching to focused scanning mode")
            
            self.centralManager.scanForPeripherals(withServices: services, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ])
        }
    }
    
    func stopScanning() {
        centralManager.stopScan()
        print("Stopped scanning for Bluetooth devices")
    }
    
    func connect(to peripheral: CBPeripheral) {
        print("Attempting to connect to \(peripheral.name ?? "Unknown Device") (\(peripheral.identifier))")
        
        // Reset discovery attempts counter
        discoveryAttempts[peripheral.identifier] = 0
        
        peripheral.delegate = self
        let options: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]
        
        centralManager.connect(peripheral, options: options)
    }
    
    func disconnect(from peripheral: CBPeripheral) {
        print("Disconnecting from \(peripheral.name ?? "Unknown Device")")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func discoverServices(for peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            print("Cannot discover services: Peripheral \(peripheral.name ?? "Unknown") is not connected")
            return
        }
        
        print("Discovering services for \(peripheral.name ?? "Unknown Device") (\(peripheral.identifier))...")
        
        // Increment discovery attempts counter
        let attempts = (discoveryAttempts[peripheral.identifier] ?? 0) + 1
        discoveryAttempts[peripheral.identifier] = attempts
        
        if attempts > maxDiscoveryAttempts {
            print("Maximum discovery attempts reached for \(peripheral.name ?? "Unknown")")
            return
        }
        
        // Look for all services initially
        peripheral.discoverServices(nil)
    }
    
    func discoverCharacteristics(for service: CBService, peripheral: CBPeripheral) {
        peripheral.discoverCharacteristics(nil, for: service)
    }
    
    func readValue(for characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        peripheral.readValue(for: characteristic)
    }
    
    func write(data: Data, to characteristic: CBCharacteristic, peripheral: CBPeripheral, type: CBCharacteristicWriteType) {
        peripheral.writeValue(data, for: characteristic, type: type)
    }
    
    func setNotify(enabled: Bool, for characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        peripheral.setNotifyValue(enabled, for: characteristic)
    }
    
    // Bağlı cihazların RSSI değerini yenilemek için kullanılır
    func refreshRSSI(for peripheral: CBPeripheral) {
        if peripheral.state == .connected {
            peripheral.readRSSI()
            print("Refreshing RSSI for \(peripheral.name ?? "Unknown Device")")
        }
    }
    
    // Improved battery level reading function
    func readBatteryLevel(for peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            print("Cannot read battery: Peripheral \(peripheral.name ?? "Unknown") is not connected")
            return
        }
        
        // First check if we already discovered the battery service
        if let batteryService = peripheral.services?.first(where: { $0.uuid == batteryServiceUUID }) {
            if let batteryCharacteristic = batteryService.characteristics?.first(where: { $0.uuid == batteryLevelCharacteristicUUID }) {
                print("Reading battery level for \(peripheral.name ?? "Unknown Device")")
                peripheral.readValue(for: batteryCharacteristic)
                
                // Set up notifications for battery updates
                peripheral.setNotifyValue(true, for: batteryCharacteristic)
            } else {
                // Discover characteristics for the battery service if not found
                print("Battery service found but characteristics not discovered")
                peripheral.discoverCharacteristics([batteryLevelCharacteristicUUID], for: batteryService)
            }
        } else {
            // If no battery service, try to discover it specifically
            print("Battery service not found, discovering specific services")
            peripheral.discoverServices([batteryServiceUUID])
        }
    }
    
    // Function to play sound on Apple devices
    func playSound(on peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            print("Cannot play sound: Peripheral is not connected")
            return
        }
        
        // Special handling for Apple devices
        if isAppleDevice(peripheral) {
            print("Detected Apple device, attempting to play sound")
            sendAppleSpecificCommand(peripheral)
            return
        }
        
        // For other devices, try standard approach
        if let audioService = peripheral.services?.first(where: { $0.uuid == audioServiceUUID }) {
            if let playCharacteristic = audioService.characteristics?.first(where: { $0.uuid == audioPlayCharacteristicUUID }) {
                // Standard play command
                let playCommand: [UInt8] = [0x01]
                let data = Data(playCommand)
                
                peripheral.writeValue(data, for: playCharacteristic, type: .withResponse)
                print("Sent play command to \(peripheral.name ?? "Unknown Device")")
            } else {
                // Try to discover characteristics if not found
                peripheral.discoverCharacteristics([audioPlayCharacteristicUUID], for: audioService)
                print("Audio service found but characteristics not discovered")
            }
        } else {
            // If no audio service is found, try to discover it
            print("Audio service not found, discovering services")
            peripheral.discoverServices([audioServiceUUID])
        }
    }
    
    // Helper method to identify Apple devices
    private func isAppleDevice(_ peripheral: CBPeripheral) -> Bool {
        // Check device name
        if let name = peripheral.name?.lowercased() {
            if name.contains("airpod") || name.contains("apple") || name.contains("iphone") || 
               name.contains("ipad") || name.contains("mac") || name.contains("watch") {
                return true
            }
        }
        
        // Check if we have advertising data with Apple's manufacturerID
        // This would need to be stored somewhere during discovery
        
        return false
    }
    
    // Apple-specific command for Find My functionality
    private func sendAppleSpecificCommand(_ peripheral: CBPeripheral) {
        // This is a placeholder - actual implementation would require Apple-specific protocols
        print("Apple-specific commands would be implemented here")
        
        // Try to discover device info service
        peripheral.discoverServices([deviceInfoServiceUUID])
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        let isPoweredOn = central.state == .poweredOn
        
        // Notify delegate of Bluetooth state change
        delegate?.bluetoothStateDidUpdate(isPoweredOn: isPoweredOn)
        
        print("📱 Bluetooth state changed to: \(central.state.rawValue) (isPoweredOn: \(isPoweredOn))")
        
        switch central.state {
        case .poweredOn:
            print("Bluetooth is powered on")
        case .poweredOff:
            print("Bluetooth is powered off")
        case .resetting:
            print("Bluetooth is resetting")
        case .unauthorized:
            print("Bluetooth is unauthorized")
        case .unsupported:
            print("Bluetooth is unsupported")
        case .unknown:
            print("Bluetooth state is unknown")
        @unknown default:
            print("Unknown Bluetooth state")
        }
    }
    
    // Bluetooth session restoration
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        print("Restoring Bluetooth state")
        
        // Restore peripherals
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            print("Restoring \(peripherals.count) peripherals")
            
            for peripheral in peripherals {
                peripheral.delegate = self
                if peripheral.state == .connected {
                    // Re-register connected peripherals
                    connectedPeripherals[peripheral.identifier] = peripheral
                    print("Restored connected peripheral: \(peripheral.name ?? "Unknown")")
                    
                    // Discover services for restored peripherals
                    peripheral.discoverServices(nil)
                }
            }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Only report discovered peripherals with a name
        if peripheral.name != nil {
            delegate?.didDiscoverDevice(peripheral: peripheral, rssi: RSSI, advertisementData: advertisementData)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        connectedPeripherals[peripheral.identifier] = peripheral
        delegate?.didConnectToDevice(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
        delegate?.didFailToConnect(peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
        connectedPeripherals.removeValue(forKey: peripheral.identifier)
        delegate?.didDisconnectFromDevice(peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services for \(peripheral.name ?? "Unknown"): \(error!.localizedDescription)")
            
            // Retry discovery on error - increment counter handled in discoverServices
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.discoverServices(for: peripheral)
            }
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            print("No services discovered for \(peripheral.name ?? "Unknown")")
            return
        }
        
        print("Discovered \(services.count) services for \(peripheral.name ?? "Unknown Device"):")
        
        // Updated to discover characteristics for all services
        for service in services {
            print("- Service: \(service.uuid.uuidString)")
            discoveredServices.append(service)
            
            // Discover characteristics for each service
            peripheral.discoverCharacteristics(nil, for: service)
            
            // Special handling for important services
            if service.uuid == batteryServiceUUID {
                print("Found battery service, discovering characteristics")
                peripheral.discoverCharacteristics([batteryLevelCharacteristicUUID], for: service)
            } else if service.uuid == audioServiceUUID {
                print("Found audio control service, discovering characteristics")
                peripheral.discoverCharacteristics([audioPlayCharacteristicUUID], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics for service \(service.uuid): \(error!.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics, !characteristics.isEmpty else {
            print("No characteristics discovered for service \(service.uuid)")
            return
        }
        
        print("Discovered \(characteristics.count) characteristics for service \(service.uuid):")
        
        for characteristic in characteristics {
            let characteristicUUID = characteristic.uuid.uuidString
            print("- Characteristic: \(characteristicUUID)")
            discoveredCharacteristics.append(characteristic)
            
            // Automatically handle important characteristics
            if characteristic.uuid == batteryLevelCharacteristicUUID {
                print("Found battery level characteristic, reading value")
                peripheral.readValue(for: characteristic)
                
                // Set up notifications for battery updates
                peripheral.setNotifyValue(true, for: characteristic)
            } else if characteristic.uuid == audioPlayCharacteristicUUID {
                print("Found audio control characteristic")
                peripheral.setNotifyValue(true, for: characteristic)
            } else {
                // Read the value for all other readable characteristics
                if characteristic.properties.contains(.read) {
                    peripheral.readValue(for: characteristic)
                }
                
                // Subscribe to notifications for all notifiable characteristics
                if characteristic.properties.contains(.notify) {
                    peripheral.setNotifyValue(true, for: characteristic)
                }
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating value for characteristic: \(error!.localizedDescription)")
            return
        }
        
        // Handle the characteristic value
        if characteristic.uuid == batteryLevelCharacteristicUUID { // Battery Level characteristic
            if let data = characteristic.value, data.count > 0 {
                let batteryLevel = data[0]
                print("Battery level for \(peripheral.name ?? "Unknown Device"): \(batteryLevel)%")
            }
        }
        
        delegate?.didUpdateValueFor(characteristic: characteristic, peripheral: peripheral)
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error writing value for characteristic: \(error!.localizedDescription)")
            return
        }
        
        print("Value written to characteristic \(characteristic.uuid)")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        guard error == nil else {
            print("Error updating notification state: \(error!.localizedDescription)")
            return
        }
        
        print("Notification state updated for characteristic \(characteristic.uuid): \(characteristic.isNotifying ? "enabled" : "disabled")")
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        guard error == nil else {
            print("Error reading RSSI: \(error!.localizedDescription)")
            return
        }
        
        print("Updated RSSI for \(peripheral.name ?? "Unknown Device"): \(RSSI)")
        // RSSI güncellendiğinde, yeni değeri DeviceManager'a bildir
        delegate?.didDiscoverDevice(peripheral: peripheral, rssi: RSSI, advertisementData: [:])
    }
}

// MARK: - RSSI Strength Extension
extension NSNumber {
    var signalStrength: SignalStrength {
        let rssi = self.intValue
        
        if rssi > -50 {
            return .excellent
        } else if rssi > -65 {
            return .good
        } else if rssi > -80 {
            return .fair
        } else {
            return .poor
        }
    }
} 