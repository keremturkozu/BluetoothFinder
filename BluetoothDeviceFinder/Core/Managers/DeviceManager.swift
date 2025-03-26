import Foundation
import CoreBluetooth
import Combine
import CoreLocation

class DeviceManager: NSObject, ObservableObject {
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
    
    // RSSI güncellemesi için timer
    private var rssiUpdateTimer: Timer?
    
    // MARK: - Initialization
    override init() {
        self.bluetoothService = BluetoothService()
        self.locationService = LocationService()
        
        super.init()
        
        setupBluetoothService()
        setupLocationService()
        loadSavedDevices()
        startRSSIUpdateTimer()
        
        // Check initial Bluetooth state
        checkAndUpdateBluetoothState()
    }
    
    deinit {
        stopRSSIUpdateTimer()
    }
    
    // MARK: - Public Methods
    func startScanning() {
        // First check if Bluetooth is available - Önce durumu güncelleyelim
        checkAndUpdateBluetoothState()
        
        if !isBluetoothEnabled {
            errorMessage = "Please enable Bluetooth in Settings to scan for devices"
            print("Cannot start scanning: Bluetooth is disabled")
            return
        }
        
        // Then check location authorization
        if !isLocationAuthorized {
            errorMessage = "Location access is required to scan for Bluetooth devices"
            print("Cannot start scanning: Location services not authorized")
            
            // Request location authorization
            locationService.requestAuthorization()
            return
        }
        
        print("Starting device scan...")
        isScanning = true
        bluetoothService.startScanning()
        
        // Scan for a reasonable time period, then stop to save battery
        DispatchQueue.main.asyncAfter(deadline: .now() + 30.0) { [weak self] in
            if self?.isScanning == true {
                self?.stopScanning()
            }
        }
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
        
        // Check if Bluetooth is enabled
        guard bluetoothService.isPoweredOn else {
            errorMessage = "Bluetooth is not enabled. Please enable Bluetooth in settings."
            return
        }
        
        // Add connection timeout
        let connectionTimeout: TimeInterval = 10.0
        let timer = Timer.scheduledTimer(withTimeInterval: connectionTimeout, repeats: false) { [weak self] _ in
            // If device is still not connected after timeout, consider connection failed
            if device.isConnected == false {
                self?.errorMessage = "Connection timed out. Please try again."
                // Update UI to show connection failed
                if let updatedDevice = self?.devices.first(where: { $0.id == device.id }) {
                    updatedDevice.isConnected = false
                    self?.updateDevice(updatedDevice)
                }
            }
        }
        
        // Store timer reference to invalidate if connection succeeds
        RunLoop.current.add(timer, forMode: .common)
        
        // Attempt connection
        print("Attempting to connect to \(device.name)")
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
    
    // Bluetooth sinyal gücünden (RSSI) mesafe hesaplama
    func calculateDistance(rssi: Int) -> Double {
        // RSSI değerine göre mesafe hesaplar
        // Bu formül sınırlı bir hassasiyete sahiptir, ancak gerçek dünyadaki hesaplamalar için kullanışlıdır
        
        // Parametreler
        let measuredPower = -59  // 1 metrede alınan sinyal gücü (cihaza göre değişebilir)
        let environmentalFactor = 2.0  // Ortam faktörü (açık alan = 2, iç mekan = 2.5-4 arası)
        
        if rssi == 0 {
            return -1.0 // RSSI hesaplanamıyor
        }
        
        // Basit path loss formülü
        let ratio = Double(rssi) / Double(measuredPower)
        if ratio < 1.0 {
            return pow(ratio, 10)
        } else {
            // Kalibrasyon için eğer cihaz çok yakınsa ve RSSI çok güçlüyse
            // Bu kısım genellikle doğru değildir, ama kısa mesafelerde keskinleştirir
            return (0.89976) * pow(ratio, 7.7095) + 0.111
        }
    }
    
    // RSSI değerini belirli aralıklarla güncelleme (daha doğru mesafe görüntüleme için)
    func refreshDeviceRSSI() {
        // Aktif cihazların RSSI değerlerini günceller
        for device in devices {
            if let peripheral = device.peripheral, peripheral.state == .connected {
                // Bağlı cihazlar için RSSI güncelleme
                bluetoothService.refreshRSSI(for: peripheral)
            }
        }
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
    
    // Enhanced play sound function with error handling
    func playSound(on device: Device) -> Bool {
        guard let peripheral = device.peripheral else {
            errorMessage = "Cannot play sound: Device does not have a valid peripheral"
            return false
        }
        
        if !device.isConnected {
            // Try to connect first
            connect(to: device)
            errorMessage = "Connecting to device first. Please try again after connected."
            return false
        }
        
        // For Apple devices, we might need special handling
        if isAppleDevice(device) {
            print("Playing sound on Apple device: \(device.name)")
        }
        
        bluetoothService.playSound(on: peripheral)
        return true
    }
    
    // Helper to identify Apple devices
    private func isAppleDevice(_ device: Device) -> Bool {
        // Check device name for keywords
        let name = device.name.lowercased()
        return name.contains("airpod") || 
               name.contains("iphone") || 
               name.contains("apple") || 
               name.contains("watch") ||
               name.contains("ipad") ||
               name.contains("mac")
    }
    
    // Şarj seviyesini oku
    func readBatteryLevel(for device: Device) {
        guard let peripheral = device.peripheral else {
            errorMessage = "Cannot read battery: Device does not have a valid peripheral"
            return
        }
        
        guard device.isConnected else {
            errorMessage = "Cannot read battery: Device is not connected"
            return
        }
        
        bluetoothService.readBatteryLevel(for: peripheral)
    }
    
    // Cihaz servislerini ve özelliklerini keşfet
    func discoverDeviceServices(for device: Device) {
        guard let peripheral = device.peripheral else {
            errorMessage = "Cannot discover services: Device does not have a valid peripheral"
            return
        }
        
        guard device.isConnected else {
            errorMessage = "Cannot discover services: Device is not connected"
            return
        }
        
        bluetoothService.discoverServices(for: peripheral)
    }
    
    // Check and update Bluetooth state
    func checkAndUpdateBluetoothState() {
        // Bluetooth durumunu güncelle
        isBluetoothEnabled = bluetoothService.isPoweredOn
        
        // Debug bilgisi
        print("📱 Bluetooth status check - isPoweredOn: \(bluetoothService.isPoweredOn)")
        
        if !isBluetoothEnabled {
            errorMessage = "Bluetooth is disabled. Please enable it in Settings."
        } else {
            // Bluetooth açıksa, önceki hata mesajını temizle
            if errorMessage == "Bluetooth is disabled. Please enable it in Settings." ||
               errorMessage == "Please enable Bluetooth in Settings to scan for devices" {
                errorMessage = nil
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupBluetoothService() {
        bluetoothService.delegate = self
        
        // Update isBluetoothEnabled based on the current Bluetooth state
        isBluetoothEnabled = bluetoothService.isPoweredOn
        
        // Debug bilgisi
        print("📱 Initial Bluetooth state: \(bluetoothService.isPoweredOn)")
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
    
    // Daha detaylı cihaz türü tespiti
    private func getDeviceType(from advertisementData: [String: Any]) -> DeviceType {
        // Önce servis UUIDlerini kontrol et
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            // Headphones ve Audio cihazlar (A2DP servisi)
            if serviceUUIDs.contains(where: { $0.uuidString.contains("110A") || $0.uuidString.contains("110B") }) {
                return .headphones
            }
            
            // Apple Watch (Apple Notification Center Service)
            if serviceUUIDs.contains(where: { $0.uuidString.contains("1801") || $0.uuidString.contains("1805") }) {
                return .watch
            }
            
            // Klavye ve Mouse HID servislerine sahip olabilir
            if serviceUUIDs.contains(where: { $0.uuidString.contains("1812") }) {
                return .keyboard  // Başlangıçta klavye diyelim, sonra isimden düzelteceğiz
            }
        }
        
        // Üretici verilerine bak
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            // Apple cihazları 0x004C manufacturer ID'sine sahiptir
            if manufacturerData.count >= 2 {
                let manufacturerID = UInt16(manufacturerData[0]) + (UInt16(manufacturerData[1]) << 8)
                if manufacturerID == 0x004C {  // Apple ürünleri
                    // Hangi Apple ürünü olduğunu belirle
                    if let localName = advertisementData[CBAdvertisementDataLocalNameKey] as? String {
                        let name = localName.lowercased()
                        if name.contains("airpod") {
                            return .headphones
                        } else if name.contains("watch") {
                            return .watch
                        } else if name.contains("phone") || name.contains("iphone") {
                            return .phone
                        } else if name.contains("ipad") || name.contains("tablet") {
                            return .tablet
                        } else if name.contains("mac") || name.contains("book") {
                            return .laptop
                        }
                    }
                    // Eğer belirli bir isim bulamazsak, bir Apple cihazı olduğunu varsayalım
                    return .phone
                }
            }
        }
        
        // İsimden cihaz türünü belirlemeye çalış
        if let localName = (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? nil {
            let lowercaseName = localName.lowercased()
            
            if lowercaseName.contains("headphone") || lowercaseName.contains("airpod") || 
               lowercaseName.contains("earbud") || lowercaseName.contains("headset") {
                return .headphones
            } else if lowercaseName.contains("speaker") || lowercaseName.contains("sound") || 
                      lowercaseName.contains("audio") {
                return .speaker
            } else if lowercaseName.contains("watch") {
                return .watch
            } else if lowercaseName.contains("keyboard") {
                return .keyboard
            } else if lowercaseName.contains("mouse") {
                return .mouse
            } else if lowercaseName.contains("phone") || lowercaseName.contains("iphone") {
                return .phone
            } else if lowercaseName.contains("ipad") || lowercaseName.contains("tablet") {
                return .tablet
            } else if lowercaseName.contains("mac") || lowercaseName.contains("book") || 
                      lowercaseName.contains("laptop") {
                return .laptop
            } else if lowercaseName.contains("computer") || lowercaseName.contains("pc") {
                return .computer
            }
        }
        
        // Eğer hiçbir şekilde belirleyemezsek bilinmeyen olarak işaretle
        return .unknown
    }
    
    private func startRSSIUpdateTimer() {
        // Her 2 saniyede bir RSSI değerlerini güncelle
        rssiUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshDeviceRSSI()
        }
    }
    
    private func stopRSSIUpdateTimer() {
        rssiUpdateTimer?.invalidate()
        rssiUpdateTimer = nil
    }
}

// MARK: - BluetoothServiceDelegate
extension DeviceManager: BluetoothServiceDelegate {
    func didDiscoverDevice(peripheral: CBPeripheral, rssi: NSNumber, advertisementData: [String: Any]) {
        let deviceName = peripheral.name ?? "Unknown Device"
        let deviceType = getDeviceType(from: advertisementData)
        
        print("Discovered device: \(deviceName) (RSSI: \(rssi))")
        
        // Check if this is an update for an existing device
        if let existingDevice = deviceDictionary[peripheral.identifier] {
            existingDevice.update(with: peripheral, rssi: rssi.intValue, advertisementData: advertisementData)
            
            // Update the device type if we have better information now
            if existingDevice.type == .unknown {
                existingDevice.type = deviceType
            }
            
            // Save the timestamp when we last saw this device
            existingDevice.lastSeen = Date()
            
            updateDevice(existingDevice)
        } else {
            // This is a new device
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
            
            // If location services are available, set the initial location
            if let currentLocation = locationService.currentLocation {
                newDevice.updateLocation(currentLocation)
            }
            
            deviceDictionary[peripheral.identifier] = newDevice
            updateDevicesList()
            
            // Auto-connect to saved devices if we rediscover them
            if let savedDevice = getSavedDeviceWithSameName(as: newDevice) {
                // This might be a previously saved device that we're seeing again with a new ID
                newDevice.isSaved = true
                connect(to: newDevice)
            }
        }
    }
    
    func didConnectToDevice(_ peripheral: CBPeripheral) {
        print("Device Manager: Connected to \(peripheral.name ?? "Unknown Device")")
        
        if let device = deviceDictionary[peripheral.identifier] {
            device.isConnected = true
            device.lastSeen = Date()
            
            // Update RSSI value for recently connected device
            bluetoothService.refreshRSSI(for: peripheral)
            
            // Automatically discover services
            bluetoothService.discoverServices(for: peripheral)
            
            // Update the device in our dictionary and list
            updateDevice(device)
            
            // Notify success
            DispatchQueue.main.async {
                self.errorMessage = nil // Clear error messages
            }
        } else {
            // If we somehow connected to a device that's not in our dictionary,
            // create a new device with the peripheral
            let newDevice = Device(
                id: peripheral.identifier,
                peripheral: peripheral,
                name: peripheral.name ?? "Unknown Device",
                isConnected: true,
                lastSeen: Date()
            )
            
            deviceDictionary[peripheral.identifier] = newDevice
            updateDevicesList()
            
            // Discover services for the new device
            bluetoothService.discoverServices(for: peripheral)
        }
    }
    
    func didDisconnectFromDevice(_ peripheral: CBPeripheral, error: Error?) {
        print("Device Manager: Disconnected from \(peripheral.name ?? "Unknown Device")")
        
        if let device = deviceDictionary[peripheral.identifier] {
            device.isConnected = false
            updateDevice(device)
            
            // If there was an error, handle it
            if let error = error {
                errorMessage = "Disconnected: \(error.localizedDescription)"
            }
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
        // Cihazı bul
        guard let deviceIndex = devices.firstIndex(where: { $0.peripheral?.identifier == peripheral.identifier }) else {
            print("Device not found for peripheral \(peripheral.name ?? "Unknown")")
            return
        }
        
        let device = devices[deviceIndex]
        
        // Hangi karakteristik güncellenmiş?
        if characteristic.uuid == CBUUID(string: "2A19") { // Battery Level Characteristic
            if let data = characteristic.value, data.count > 0 {
                let batteryLevel = Int(data[0])
                print("Battery level updated for \(device.name): \(batteryLevel)%")
                
                // Pil seviyesini güncelle
                device.batteryLevel = batteryLevel
                updateDevice(device)
            }
        }
        
        // Diğer karakteristikleri de burada işleyebiliriz
    }
    
    // Add notification for state changes
    func bluetoothStateDidUpdate(isPoweredOn: Bool) {
        DispatchQueue.main.async {
            self.isBluetoothEnabled = isPoweredOn
            
            if !isPoweredOn {
                // Stop scanning if Bluetooth is turned off
                if self.isScanning {
                    self.stopScanning()
                }
                
                // Update error message
                self.errorMessage = "Bluetooth is turned off. Please enable it in Settings."
            } else {
                // Clear error message if it was about Bluetooth being off
                if self.errorMessage == "Bluetooth is disabled. Please enable it in Settings." ||
                   self.errorMessage == "Please enable Bluetooth in Settings to scan for devices" {
                    self.errorMessage = nil
                }
            }
        }
    }
}

// MARK: - Additional Helper Methods
extension DeviceManager {
    // Helper to find previously saved devices with the same name
    private func getSavedDeviceWithSameName(as device: Device) -> Device? {
        return devices.first { $0.isSaved && $0.name == device.name && $0.id != device.id }
    }
    
    // When UI requests a battery level update
    func updateBatteryLevel(for device: Device) {
        guard device.isConnected, let peripheral = device.peripheral else {
            print("Cannot update battery: Device not connected")
            return
        }
        
        // Try to read battery level
        bluetoothService.readBatteryLevel(for: peripheral)
    }
    
    // Vibrate a device (if supported)
    func vibrateDevice(_ device: Device) -> Bool {
        guard device.isConnected, let peripheral = device.peripheral else {
            errorMessage = "Cannot vibrate: Device not connected"
            return false
        }
        
        // This is a placeholder - actual implementation depends on device support
        print("Attempting to vibrate \(device.name)")
        
        // For now, return success to show UI feedback
        return true
    }
} 