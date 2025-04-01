import Foundation
import CoreBluetooth
import Combine
import CoreLocation
import AudioToolbox

class DeviceManager: NSObject, ObservableObject {
    // MARK: - Properties
    @Published var devices: [Device] = []
    @Published var isScanning: Bool = false
    @Published var errorMessage: String?
    @Published var isBluetoothEnabled: Bool = false
    @Published var isLocationAuthorized: Bool = false
    
    private var deviceDictionary: [UUID: Device] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    let bluetoothService: BluetoothService
    let locationService: LocationService
    let notificationService = NotificationService()
    
    // Simülasyon modu durumu
    var simulationMode: Bool {
        return bluetoothService.isSimulationModeEnabled
    }
    
    // MARK: - Initialization
    override init() {
        self.bluetoothService = BluetoothService()
        self.locationService = LocationService()
        
        super.init()
        
        setupBluetoothService()
        setupLocationService()
        
        // Initial state checks
        isBluetoothEnabled = bluetoothService.isPoweredOn
    }
    
    // MARK: - Public Methods
    func startScanning() {
        // Zaten tarama yapılıyorsa, tekrar başlatma
        if isScanning {
            return
        }
        
        // Bluetooth devre dışıysa, kullanıcıyı bilgilendir
        guard isBluetoothEnabled else {
            errorMessage = "Please enable Bluetooth to start scanning"
            return
        }
        
        // Taramayı başlat
        bluetoothService.startScanning()
        isScanning = true
        print("Scanning started")
        
        // Taramayı başlattıktan sonra, simülatör modunda cihaz simülasyonu yap
        
        
        // 60 saniye sonra taramayı otomatik olarak durdur
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
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
        // Simülasyon modunda bağlantı davranışını hemen güncelle
        if simulationMode {
            DispatchQueue.main.async {
                // Simule edilmiş bir cihaza bağlanma
                device.isConnected = true
                self.updateDevice(device)
                
                // Rastgele pil seviyesi ata (gerçek bir cihaz olmadığı için)
                if device.batteryLevel == nil {
                    device.batteryLevel = Int.random(in: 10...100)
                    self.updateDevice(device)
                }
                
                // 2 saniye sonra bağlantı başarılı bildirimi
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.notificationService.showNotification(
                        title: "Device Connected",
                        body: "Connected to \(device.name) successfully"
                    )
                }
            }
            return
        }
        
        // Gerçek bir cihaz bağlantısı için
        guard let peripheral = device.peripheral else {
            errorMessage = "Cannot connect: Device does not have a valid peripheral"
            return
        }
        
        bluetoothService.connect(to: peripheral)
    }
    
    func disconnect(from device: Device) {
        // Simülasyon modunda hemen bağlantıyı kes
        if simulationMode {
            device.isConnected = false
            updateDevice(device)
            return
        }
        
        guard let peripheral = device.peripheral else { return }
        bluetoothService.disconnect(from: peripheral)
    }
    
    // MARK: - Device Management Functions
    
    // Mark a device as found
    func deviceFound(_ device: Device) {
        guard let foundDevice = deviceDictionary[device.id] else { return }
        foundDevice.isConnected = false
        foundDevice.isSaved = false
        
        // Remove from active devices list
        deviceDictionary.removeValue(forKey: device.id)
        updateDevicesList()
    }
    
    // Save a device to favorites
    func saveDevice(_ device: Device) {
        guard let savedDevice = deviceDictionary[device.id] else { return }
        savedDevice.isSaved = true
        updateDevice(savedDevice)
    }
    
    // Toggle saved status for a device
    func toggleSaveDevice(_ device: Device) {
        guard let targetDevice = deviceDictionary[device.id] else { return }
        targetDevice.isSaved = !targetDevice.isSaved
        updateDevice(targetDevice)
    }
    
    // Update battery level for a device
    func updateBatteryLevel(for device: Device) {
        // Simülasyon modunda rastgele pil seviyesi güncelle
        if simulationMode {
            // Rastgele bir değer oluştur, ancak mevcut değerden çok farklı olmasın
            let currentLevel = device.batteryLevel ?? Int.random(in: 30...100)
            let variation = Int.random(in: -5...0) // Pil seviyesi zamanla azalır
            let newLevel = max(1, min(100, currentLevel + variation))
            
            device.batteryLevel = newLevel
            updateDevice(device)
            return
        }
        
        // Gerçek cihaz için pil seviyesi okuma
        guard let peripheral = device.peripheral else { return }
        bluetoothService.readBatteryLevel(for: peripheral)
    }
    
    // Read battery level for a device
    func readBatteryLevel(for device: Device) {
        // Simülasyon modunda eğer pil seviyesi yoksa başlangıç değeri ata
        if simulationMode {
            if device.batteryLevel == nil {
                device.batteryLevel = Int.random(in: 10...100)
                updateDevice(device)
            }
            return
        }
        
        // Gerçek cihaz için
        guard let peripheral = device.peripheral else { return }
        bluetoothService.readBatteryLevel(for: peripheral)
    }
    
    // Play sound on device
    func playSound() {
        // Simülasyon modunda ses çalma
        if simulationMode {
            // Gerçek bir ses çalamazsınız, sadece bildirim gösterin
            notificationService.showNotification(
                title: "Playing Sound",
                body: "Sound is playing on the device (simulated)"
            )
            
            // Yerel cihazda geri bildirim sağlayın
            AudioServicesPlaySystemSound(1521) // Standart bildirim sesi
            return
        }
        
        // Gerçek bir cihazda ses çalma işlemi
        // Bağlı tüm cihazlarda ses çalmayı deneyelim
        var soundPlayed = false
        for (_, device) in deviceDictionary {
            if device.isConnected, let peripheral = device.peripheral {
                bluetoothService.playSound(on: peripheral)
                soundPlayed = true
                
                notificationService.showNotification(
                    title: "Playing Sound",
                    body: "Sound is playing on \(device.name)"
                )
            }
        }
        
        if !soundPlayed {
            notificationService.showNotification(
                title: "Cannot Play Sound",
                body: "No connected devices found"
            )
        }
    }
    
    // Vibrate device
    func vibrateDevice() {
        // Simülasyon modunda titreşim
        if simulationMode {
            // Gerçek bir titreşim yapamayız, sadece bildirim gösterin
            notificationService.showNotification(
                title: "Vibrating Device",
                body: "Device is vibrating (simulated)"
            )
            
            // Yerel cihazda geri bildirim sağlayın
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            return
        }
        
        // Gerçek bir cihazda titreşim işlemi
        // Bağlı tüm cihazlarda titreşim başlatmayı deneyelim
        var vibrationStarted = false
        for (_, device) in deviceDictionary {
            if device.isConnected, let peripheral = device.peripheral {
                bluetoothService.vibrateDevice(on: peripheral)
                vibrationStarted = true
                
                notificationService.showNotification(
                    title: "Vibrating Device",
                    body: "Vibration started on \(device.name)"
                )
            }
        }
        
        if !vibrationStarted {
            notificationService.showNotification(
                title: "Cannot Start Vibration",
                body: "No connected devices found"
            )
        }
    }
    
    // Discover services for a device
    func discoverDeviceServices(for device: Device) {
        // Implementation would depend on what services you want to discover
        // This is a placeholder function since it's referred to in errors
    }
    
    // Calculate distance to a device based on RSSI
    func calculateDistance(rssi: Int?) -> Double {
        guard let rssi = rssi else { return 10.0 } // Default to 10 meters if no RSSI
        
        let txPower = -59 // RSSI at 1 meter (can be calibrated)
        let n = 2.5 // Path loss exponent (environment dependent)
        
        return pow(10, (Double(txPower - rssi) / (10 * n)))
    }
    
    // Calculate distance to a device and return formatted string
    func calculateDistance(to device: Device) -> String {
        if let location = device.lastLocation, let userLocation = locationService.currentLocation {
            // If we have both device and user location, use geographical distance
            let distance = location.distance(from: userLocation)
            return formatDistance(distance)
        } else if let rssi = device.rssi, rssi != 0 {
            // Otherwise estimate from RSSI
            let distance = calculateDistance(rssi: rssi)
            return formatDistance(distance)
        } else {
            return "Unknown"
        }
    }
    
    // Helper to format distance
    public func formatDistance(_ distance: Double) -> String {
        if distance < 1 {
            // If less than 1 meter, show in cm
            return String(format: "%.0f cm", distance * 100)
        } else if distance < 10 {
            // If less than 10 meters, show with decimal
            return String(format: "%.1f m", distance)
        } else {
            // Otherwise show as whole meters
            return String(format: "%.0f m", distance)
        }
    }
    
    // Check and update Bluetooth state
    func checkBluetoothState() {
        // Update Bluetooth status
        isBluetoothEnabled = bluetoothService.isPoweredOn
        
        if isBluetoothEnabled {
            print("📱 Bluetooth is enabled")
        } else {
            print("📱 Bluetooth is disabled")
            errorMessage = "Please enable Bluetooth to scan for devices"
            
            // Stop scanning if it was in progress
            if isScanning {
                stopScanning()
            }
        }
    }
    
    // Update device location
    func updateDeviceLocation(_ device: Device) {
        guard let currentLocation = locationService.currentLocation else { return }
        guard let updateDevice = deviceDictionary[device.id] else { return }
        updateDevice.updateLocation(currentLocation)
        self.updateDevice(updateDevice)
    }
    
    // Remove a device
    func removeDevice(_ device: Device) {
        deviceDictionary.removeValue(forKey: device.id)
        updateDevicesList()
    }
    
    // MARK: - Private Methods
    private func setupBluetoothService() {
        bluetoothService.delegate = self
        
        // Listen for Bluetooth state changes
        isBluetoothEnabled = bluetoothService.isPoweredOn
    }
    
    private func setupLocationService() {
        // Setup binding to location authorization status
        locationService.$authorizationStatus
            .sink { [weak self] status in
                self?.isLocationAuthorized = (status == .authorizedWhenInUse || status == .authorizedAlways)
            }
            .store(in: &cancellables)
    }
    
    private func updateDevicesList() {
        devices = Array(deviceDictionary.values).sorted { $0.name < $1.name }
    }
    
    func updateDevice(_ device: Device) {
        deviceDictionary[device.id] = device
        updateDevicesList()
    }
    
    // Helper to determine device type from advertisement data
    private func determineDeviceType(from advertisementData: [String: Any], name: String) -> DeviceType {
        let lowercaseName = name.lowercased()
        
        if lowercaseName.contains("airpod") || lowercaseName.contains("headphone") || 
           lowercaseName.contains("earbud") {
            return .headphones
        } else if lowercaseName.contains("watch") {
            return .watch
        } else if lowercaseName.contains("iphone") || lowercaseName.contains("phone") {
            return .phone
        } else if lowercaseName.contains("mac") || lowercaseName.contains("book") {
            return .laptop
        } else if lowercaseName.contains("mouse") {
            return .mouse
        } else if lowercaseName.contains("keyboard") {
            return .keyboard
        }
        
        return .unknown
    }
    
    // Belirli bir cihaza özel işlevler için
    func playSound(on device: Device) {
        guard device.isConnected, let peripheral = device.peripheral else {
            notificationService.showNotification(
                title: "Cannot Play Sound",
                body: "Device is not connected"
            )
            return
        }
        
        // Apple Watch için özel işlem
        if device.type == .watch {
            print("📱 Using Apple Watch specific sound method for \(device.name)")
            bluetoothService.playSoundOnAppleWatch(peripheral: peripheral)
        } else {
            // Diğer cihazlar için standard metod
            bluetoothService.playSound(on: peripheral)
        }
        
        // Her durumda kullanıcıya bildiri göster
        notificationService.showNotification(
            title: "Playing Sound",
            body: "Sound is playing on \(device.name)"
        )
    }
    
    func vibrateDevice(on device: Device) {
        guard device.isConnected, let peripheral = device.peripheral else {
            notificationService.showNotification(
                title: "Cannot Vibrate Device",
                body: "Device is not connected"
            )
            return
        }
        
        // Apple Watch için özel işlem
        if device.type == .watch {
            print("📱 Using Apple Watch specific vibration method for \(device.name)")
            bluetoothService.vibrateAppleWatch(peripheral: peripheral)
        } else {
            // Diğer cihazlar için standard metod
            bluetoothService.vibrateDevice(on: peripheral)
        }
        
        // Her durumda kullanıcıya bildiri göster
        notificationService.showNotification(
            title: "Vibrating Device",
            body: "Vibration started on \(device.name)"
        )
    }
}

// MARK: - BluetoothServiceDelegate
extension DeviceManager: BluetoothServiceDelegate {
    func didDiscoverDevice(peripheral: CBPeripheral?, rssi: NSNumber, advertisementData: [String: Any]) {
        // Simulated device için
        if peripheral == nil {
            if let deviceUUID = advertisementData["DeviceUUID"] as? UUID {
                
                // Check if this is an update for an existing simulated device
                if let existingDevice = deviceDictionary[deviceUUID] {
                    // Update existing device
                    existingDevice.rssi = rssi.intValue
                    existingDevice.lastSeen = Date()
                    updateDevice(existingDevice)
                } else {
                    // Create a new simulated device
                    let deviceName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown Device"
                    let type = advertisementData["DeviceType"] as? String ?? "unknown"
                    let deviceType = DeviceType(rawValue: type) ?? .unknown
                    
                    // Create a new simulated device
                    let newDevice = Device(
                        id: deviceUUID,
                        peripheral: nil,
                        name: deviceName,
                        rssi: rssi.intValue,
                        batteryLevel: nil,
                        isConnected: false,
                        lastSeen: Date(),
                        type: deviceType
                    )
                    
                    // Set location if available
                    if let currentLocation = locationService.currentLocation {
                        newDevice.updateLocation(currentLocation)
                    }
                    
                    deviceDictionary[deviceUUID] = newDevice
                    updateDevicesList()
                }
            }
            return
        }
        
        // Gerçek device için log ekleyelim
        print("📱 Discovered device: \(peripheral?.name ?? "Unnamed") - RSSI: \(rssi)")
        
        // Cihaz adını al (name nil ise identifier kullan)
        let deviceName = peripheral!.name ?? "Device \(peripheral!.identifier.uuidString.prefix(4))"
        
        // Bu cihaz için mevcut bir kayıt var mı kontrol et
        if let existingDevice = deviceDictionary[peripheral!.identifier] {
            // Mevcut cihazı güncelle
            existingDevice.rssi = rssi.intValue
            existingDevice.lastSeen = Date()
            updateDevice(existingDevice)
        } else {
            // Yeni bir cihaz oluştur
            let deviceType = determineDeviceType(from: advertisementData, name: deviceName)
            let newDevice = Device(
                id: peripheral!.identifier,
                peripheral: peripheral,
                name: deviceName,
                rssi: rssi.intValue,
                batteryLevel: nil,
                isConnected: false,
                lastSeen: Date(),
                type: deviceType
            )
            
            // Eğer konum bilgisi varsa ayarla
            if let currentLocation = locationService.currentLocation {
                newDevice.updateLocation(currentLocation)
            }
            
            deviceDictionary[peripheral!.identifier] = newDevice
            updateDevicesList()
            
            // Yeni bir Apple cihazı bulunduğunda bildirim göster
            if deviceType != .unknown && isAppleDevice(deviceType) {
                notificationService.showNotification(
                    title: "New Apple Device Found",
                    body: "Discovered \(deviceName) nearby"
                )
            }
        }
    }
    
    // Apple cihazı olup olmadığını belirle
    private func isAppleDevice(_ type: DeviceType) -> Bool {
        return [.watch, .phone, .tablet, .headphones].contains(type)
    }
    
    func didConnectToDevice(_ peripheral: CBPeripheral) {
        print("📱 Connected to \(peripheral.name ?? "Unknown Device")")
        
        if let device = deviceDictionary[peripheral.identifier] {
            device.isConnected = true
            device.lastSeen = Date()
            updateDevice(device)
            
            // Bağlantı kurulan cihaz için bildirim göster 
            notificationService.showNotification(
                title: "Device Connected",
                body: "Successfully connected to \(device.name)"
            )
            
            // Bağlantıdan 2 saniye sonra pil seviyesi okumayı dene
            // Bu gecikme, servislerin keşfedilmesi için zaman tanır
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.readBatteryLevel(for: device)
            }
        }
    }
    
    func didDisconnectFromDevice(_ peripheral: CBPeripheral, error: Error?) {
        print("📱 Disconnected from \(peripheral.name ?? "Unknown Device")")
        
        if let device = deviceDictionary[peripheral.identifier] {
            device.isConnected = false
            updateDevice(device)
            
            // Cihaz bağlantısı kesildiğinde bildirim göster
            if let error = error {
                // Hata ile bağlantı kesilme durumu
                notificationService.showNotification(
                    title: "Connection Lost",
                    body: "Disconnected from \(device.name): \(error.localizedDescription)"
                )
            } else {
                // Normal bağlantı kesme durumu
                notificationService.showNotification(
                    title: "Device Disconnected",
                    body: "Disconnected from \(device.name)"
                )
            }
        }
    }
    
    func didFailToConnect(_ peripheral: CBPeripheral, error: Error?) {
        print("📱 Failed to connect to \(peripheral.name ?? "Unknown Device")")
        
        if let device = deviceDictionary[peripheral.identifier] {
            device.isConnected = false
            updateDevice(device)
            
            // Bağlantı hatası için bildirim göster
            let errorMessage = error?.localizedDescription ?? "Unknown error"
            notificationService.showNotification(
                title: "Connection Failed",
                body: "Could not connect to \(device.name): \(errorMessage)"
            )
        }
    }
    
    func didUpdateValueFor(characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        // Log all characteristic value updates
        print("📱 Value updated for characteristic: \(characteristic.uuid)")
        
        // Handle specific characteristic values (like battery level)
        if characteristic.uuid.uuidString == "2A19" { // Battery Level
            if let data = characteristic.value, data.count > 0 {
                let batteryLevel = Int(data[0])
                print("🔋 Battery level for \(peripheral.name ?? "Unknown"): \(batteryLevel)%")
                
                if let device = deviceDictionary[peripheral.identifier] {
                    device.batteryLevel = batteryLevel
                    
                    // Bildirim göster (önemli bir değişiklik)
                    if batteryLevel <= 20 {
                        notificationService.showNotification(
                            title: "Low Battery",
                            body: "\(device.name) battery is low (\(batteryLevel)%)"
                        )
                    }
                    
                    // Device güncelleniyor - bu adım çok önemli!
                    updateDevice(device)
                }
            }
        }
        // Device Information Service karakteristikleri
        else if characteristic.uuid.uuidString == "2A24" { // Model Number String
            if let data = characteristic.value, let modelName = String(data: data, encoding: .utf8) {
                print("📱 Model Number: \(modelName)")
            }
        }
        else if characteristic.uuid.uuidString == "2A25" { // Serial Number String
            if let data = characteristic.value, let serialNumber = String(data: data, encoding: .utf8) {
                print("📱 Serial Number: \(serialNumber)")
            }
        }
        else if characteristic.uuid.uuidString == "2A27" { // Hardware Revision String
            if let data = characteristic.value, let hardwareRev = String(data: data, encoding: .utf8) {
                print("📱 Hardware Revision: \(hardwareRev)")
            }
        }
        else if characteristic.uuid.uuidString == "2A26" { // Firmware Revision String
            if let data = characteristic.value, let firmwareRev = String(data: data, encoding: .utf8) {
                print("📱 Firmware Revision: \(firmwareRev)")
            }
        }
        else if characteristic.uuid.uuidString == "2A29" { // Manufacturer Name String
            if let data = characteristic.value, let manufacturer = String(data: data, encoding: .utf8) {
                print("📱 Manufacturer: \(manufacturer)")
                
                if let device = deviceDictionary[peripheral.identifier] {
                    // Apple cihazları daha doğru şekilde tespit edebiliriz
                    if manufacturer.lowercased().contains("apple") {
                        if device.name.lowercased().contains("watch") {
                            device.type = .watch
                        } else if device.name.lowercased().contains("macbook") || 
                                  device.name.lowercased().contains("mac") {
                            device.type = .laptop
                        } else if device.name.lowercased().contains("iphone") ||
                                  device.name.lowercased().contains("phone") {
                            device.type = .phone
                        } else if device.name.lowercased().contains("air") && 
                                  device.name.lowercased().contains("pod") {
                            device.type = .headphones
                        }
                        updateDevice(device)
                    }
                }
            }
        }
        // Diğer tüm karakteristik değerlerini logla
        else if let data = characteristic.value, !data.isEmpty {
            print("📱 Received data for \(characteristic.uuid.uuidString): \(data.count) bytes")
        }
    }
    
    func bluetoothStateDidUpdate(isPoweredOn: Bool) {
        isBluetoothEnabled = isPoweredOn
        
        if !isPoweredOn {
            // If Bluetooth turned off, stop scanning
            if isScanning {
                stopScanning()
            }
            errorMessage = "Bluetooth is turned off. Please enable it in Settings."
        } else {
            // Clear Bluetooth-related error messages
            if errorMessage == "Bluetooth is disabled. Please enable it in Settings." || 
               errorMessage == "Please enable Bluetooth in Settings to scan for devices" {
                errorMessage = nil
            }
        }
    }
} 
