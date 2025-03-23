import Foundation
import CoreBluetooth
import Combine

protocol BluetoothServiceProtocol {
    var discoveredDevices: [Device] { get }
    var statePublisher: AnyPublisher<CBManagerState, Never> { get }
    var devicesPublisher: AnyPublisher<[Device], Never> { get }
    
    func startScanning()
    func stopScanning()
    func connect(to device: Device)
    func disconnect(from device: Device)
}

class BluetoothService: NSObject, BluetoothServiceProtocol, ObservableObject {
    // MARK: - Properties
    private var centralManager: CBCentralManager!
    private var discoveredPeripherals: [String: CBPeripheral] = [:]
    
    @Published private(set) var discoveredDevices: [Device] = []
    private let stateSubject = PassthroughSubject<CBManagerState, Never>()
    private let devicesSubject = PassthroughSubject<[Device], Never>()
    
    var statePublisher: AnyPublisher<CBManagerState, Never> {
        stateSubject.eraseToAnyPublisher()
    }
    
    var devicesPublisher: AnyPublisher<[Device], Never> {
        devicesSubject.eraseToAnyPublisher()
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
    }
    
    func stopScanning() {
        centralManager.stopScan()
    }
    
    func connect(to device: Device) {
        guard let peripheral = discoveredPeripherals[device.identifier] else { return }
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect(from device: Device) {
        guard let peripheral = discoveredPeripherals[device.identifier] else { return }
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    // MARK: - Private Methods
    private func updateDevice(peripheral: CBPeripheral, rssi: NSNumber) {
        let identifier = peripheral.identifier.uuidString
        
        if let index = discoveredDevices.firstIndex(where: { $0.identifier == identifier }) {
            var updatedDevice = discoveredDevices[index]
            updatedDevice.rssi = rssi.intValue
            updatedDevice.lastSeen = Date()
            discoveredDevices[index] = updatedDevice
        } else {
            let newDevice = Device(
                name: peripheral.name ?? "Unknown Device",
                identifier: identifier,
                rssi: rssi.intValue
            )
            discoveredDevices.append(newDevice)
            discoveredPeripherals[identifier] = peripheral
        }
        
        devicesSubject.send(discoveredDevices)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateSubject.send(central.state)
        
        if central.state == .poweredOn {
            startScanning()
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        updateDevice(peripheral: peripheral, rssi: RSSI)
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        let identifier = peripheral.identifier.uuidString
        if let index = discoveredDevices.firstIndex(where: { $0.identifier == identifier }) {
            var updatedDevice = discoveredDevices[index]
            updatedDevice.isConnected = true
            discoveredDevices[index] = updatedDevice
            devicesSubject.send(discoveredDevices)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        let identifier = peripheral.identifier.uuidString
        if let index = discoveredDevices.firstIndex(where: { $0.identifier == identifier }) {
            var updatedDevice = discoveredDevices[index]
            updatedDevice.isConnected = false
            discoveredDevices[index] = updatedDevice
            devicesSubject.send(discoveredDevices)
        }
    }
} 