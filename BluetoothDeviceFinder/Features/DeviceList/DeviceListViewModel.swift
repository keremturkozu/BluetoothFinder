import Foundation
import SwiftUI
import Combine
import CoreLocation

class DeviceListViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var devices: [Device] = []
    @Published var filteredDevices: [Device] = []
    @Published var isScanning: Bool = false
    @Published var isBluetoothEnabled: Bool = false
    @Published var isLocationAuthorized = false
    @Published var selectedDevice: Device?
    @Published var errorMessage: String? = nil
    @Published var hideUnnamedDevices: Bool = true
    
    // MARK: - Private Properties
    private let deviceManager: DeviceManager
    private var cancellables = Set<AnyCancellable>()
    private var sortMethod: SortMethod = .name
    
    // MARK: - Initialization
    init(deviceManager: DeviceManager = DeviceManager()) {
        self.deviceManager = deviceManager
        setupBindings()
        // Her 1 saniyede bir cihaz listesini güncelle
        setupPeriodicUpdates()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Bind to device manager properties
        deviceManager.$devices
            .sink { [weak self] devices in
                self?.devices = devices
                self?.filterDevices()
            }
            .store(in: &cancellables)
        
        deviceManager.$isScanning
            .assign(to: &$isScanning)
        
        deviceManager.$isBluetoothEnabled
            .assign(to: &$isBluetoothEnabled)
        
        deviceManager.$errorMessage
            .assign(to: &$errorMessage)
        
        // İsimsiz cihazları gizleme ayarı değiştiğinde filtrelemeyi yeniden uygula
        $hideUnnamedDevices
            .sink { [weak self] _ in
                self?.filterDevices()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Filtering
    
    /// İsimsiz cihazları filtrele
    private func filterDevices() {
        if hideUnnamedDevices {
            filteredDevices = devices.filter { device in
                !isUnnamedDevice(device.name)
            }
        } else {
            filteredDevices = devices
        }
    }
    
    /// Bir cihazın isimsiz olup olmadığını kontrol et
    private func isUnnamedDevice(_ name: String) -> Bool {
        // Boş isimler
        if name.isEmpty { return true }
        
        // Genel jenerik isimler
        let genericNames = [
            "Unknown Device",
            "Bluetooth Device",
            "BT Device",
            "My Device",
            "Accessory"
        ]
        
        if genericNames.contains(name) { return true }
        
        // Belirli prefixler ile başlayanlar
        let genericPrefixes = [
            "Device",
            "LE-",
            "BT-",
            "Unknown"
        ]
        
        for prefix in genericPrefixes {
            if name.hasPrefix(prefix) { return true }
        }
        
        // Sadece sayı ve sembollerden oluşanlar (UUID gibi)
        let nonAlpha = name.filter { !$0.isLetter }
        if nonAlpha.count > name.count / 2 { return true }
        
        return false
    }
    
    /// İsimsiz cihazları göster/gizle
    func toggleHideUnnamedDevices() {
        hideUnnamedDevices.toggle()
    }
    
    // MARK: - Public Methods
    
    /// Check the current Bluetooth status
    func checkBluetoothStatus() {
        isBluetoothEnabled = deviceManager.isBluetoothEnabled
    }
    
    /// Start scanning for Bluetooth devices
    func startScanning() {
        deviceManager.startScanning()
    }
    
    /// Stop scanning for Bluetooth devices
    func stopScanning() {
        deviceManager.stopScanning()
    }
    
    /// Connect to a specific device
    func connect(to device: Device) {
        deviceManager.connect(to: device)
    }
    
    /// Disconnect from a specific device
    func disconnect(from device: Device) {
        deviceManager.disconnect(from: device)
    }
    
    /// Mark a device as saved or remove it from saved devices
    func toggleSaveDevice(_ device: Device) {
        device.isSaved.toggle()
    }
    
    /// Refresh the device list
    func refreshDevices() {
        // Stop and restart scanning to refresh the device list
        if isScanning {
            stopScanning()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.startScanning()
            }
        } else {
            startScanning()
        }
    }
    
    /// Select a device for detail view
    func selectDevice(_ device: Device) {
        selectedDevice = device
    }
    
    /// Sort devices by name
    func sortByName() {
        devices.sort { $0.name < $1.name }
        filterDevices()
    }
    
    /// Sort devices by signal strength
    func sortBySignalStrength() {
        devices.sort { ($0.rssi ?? -100) > ($1.rssi ?? -100) }
        filterDevices()
    }
    
    /// Sort devices by last seen date
    func sortByLastSeen() {
        devices.sort {
            guard let date1 = $0.lastSeen, let date2 = $1.lastSeen else {
                // If one has a lastSeen date and the other doesn't, prioritize the one with a date
                if $0.lastSeen != nil { return true }
                if $1.lastSeen != nil { return false }
                // If neither has a date, sort by name
                return $0.name < $1.name
            }
            return date1 > date2
        }
        filterDevices()
    }
    
    // MARK: - Private Methods
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
