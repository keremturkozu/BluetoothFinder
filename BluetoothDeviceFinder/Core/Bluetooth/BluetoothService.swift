import Foundation
import CoreBluetooth
import Combine

protocol BluetoothServiceDelegate: AnyObject {
    func didDiscoverDevice(peripheral: CBPeripheral, rssi: NSNumber, advertisementData: [String: Any])
    func didConnectToDevice(_ peripheral: CBPeripheral)
    func didDisconnectFromDevice(_ peripheral: CBPeripheral, error: Error?)
    func didFailToConnect(_ peripheral: CBPeripheral, error: Error?)
    func didUpdateValueFor(characteristic: CBCharacteristic, peripheral: CBPeripheral)
}

class BluetoothService: NSObject {
    // MARK: - Properties
    private var centralManager: CBCentralManager!
    private var connectedPeripherals: [CBPeripheral] = []
    private var discoveredServices: [CBService] = []
    private var discoveredCharacteristics: [CBCharacteristic] = []
    
    weak var delegate: BluetoothServiceDelegate?
    
    var isScanning: Bool {
        return centralManager.isScanning
    }
    
    var isPoweredOn: Bool {
        return centralManager.state == .poweredOn
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else {
            print("Bluetooth is not available")
            return
        }
        
        centralManager.scanForPeripherals(withServices: nil, options: [
            CBCentralManagerScanOptionAllowDuplicatesKey: false
        ])
        
        print("Started scanning for Bluetooth devices")
    }
    
    func stopScanning() {
        centralManager.stopScan()
        print("Stopped scanning for Bluetooth devices")
    }
    
    func connect(to peripheral: CBPeripheral) {
        print("Attempting to connect to \(peripheral.name ?? "Unknown Device")")
        peripheral.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect(from peripheral: CBPeripheral) {
        print("Disconnecting from \(peripheral.name ?? "Unknown Device")")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func discoverServices(for peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            print("Cannot discover services: Peripheral is not connected")
            return
        }
        
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
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
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
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        // Only report discovered peripherals with a name
        if peripheral.name != nil {
            delegate?.didDiscoverDevice(peripheral: peripheral, rssi: RSSI, advertisementData: advertisementData)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown Device")")
        connectedPeripherals.append(peripheral)
        delegate?.didConnectToDevice(peripheral)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect to \(peripheral.name ?? "Unknown Device"): \(error?.localizedDescription ?? "Unknown error")")
        delegate?.didFailToConnect(peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected from \(peripheral.name ?? "Unknown Device")")
        if let index = connectedPeripherals.firstIndex(of: peripheral) {
            connectedPeripherals.remove(at: index)
        }
        delegate?.didDisconnectFromDevice(peripheral, error: error)
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil else {
            print("Error discovering services: \(error!.localizedDescription)")
            return
        }
        
        if let services = peripheral.services {
            discoveredServices = services
            for service in services {
                print("Discovered service: \(service.uuid)")
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil else {
            print("Error discovering characteristics: \(error!.localizedDescription)")
            return
        }
        
        if let characteristics = service.characteristics {
            discoveredCharacteristics.append(contentsOf: characteristics)
            for characteristic in characteristics {
                print("Discovered characteristic: \(characteristic.uuid)")
                
                // If it's a battery level characteristic, read its value
                if characteristic.uuid == CBUUID(string: "2A19") { // Battery Level characteristic
                    peripheral.readValue(for: characteristic)
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
        if characteristic.uuid == CBUUID(string: "2A19") { // Battery Level characteristic
            if let data = characteristic.value, data.count > 0 {
                let batteryLevel = data[0]
                print("Battery level: \(batteryLevel)%")
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