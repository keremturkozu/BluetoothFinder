import Foundation
import CoreLocation
import Combine
import SwiftUI

class RadarViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var devices: [Device] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var selectedDevice: Device?
    @Published var closestDevice: Device?
    @Published var radarAngle: Double = 0
    @Published var isAnimating: Bool = false
    @Published var hideUnnamedDevices: Bool = true
    
    // Computed property for filtered devices
    var filteredDevices: [Device] {
        guard let deviceManager = deviceManager else { return [] }
        
        let allDevices = deviceManager.devices
        
        if hideUnnamedDevices {
            return allDevices.filter { !isGenericName($0.name) }
        } else {
            return allDevices
        }
    }
    
    // MARK: - Private Properties
    private var deviceManager: DeviceManager?
    private var cancellables = Set<AnyCancellable>()
    private var animationTimer: Timer?
    private let animationSpeed: Double = 0.05 // Radar rotation speed
    
    // MARK: - Initialization
    init() {
        // Radar animasyonunu başlat
        startRadarAnimation()
    }
    
    // MARK: - Dependency Injection
    func injectDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        
        // deviceManager'dan alınan cihazları doğrudan devices property'ye ata
        self.devices = deviceManager.devices
        
        // deviceManager'dan tarama durumunu aktar
        self.isScanning = deviceManager.isScanning
        
        // Backend bağlantılarını kur
        setupBindings()
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard let deviceManager = deviceManager else { return }
        deviceManager.startScanning()
        startRadarAnimation()
    }
    
    func stopScanning() {
        guard let deviceManager = deviceManager else { return }
        deviceManager.stopScanning()
        stopRadarAnimation()
    }
    
    func selectDevice(_ device: Device) {
        selectedDevice = device
    }
    
    func saveDevice(_ device: Device) {
        guard let deviceManager = deviceManager else { return }
        deviceManager.saveDevice(device)
    }
    
    func toggleScanning() {
        if isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }
    
    func updateClosestDevice() {
        guard let currentLocation = deviceManager?.locationService.currentLocation else {
            closestDevice = nil
            return
        }
        
        // Filter devices with location and sort by distance
        let devicesWithLocation = devices.filter { $0.lastLocation != nil }
        
        if !devicesWithLocation.isEmpty {
            closestDevice = devicesWithLocation.min(by: { 
                $0.lastLocation!.distance(from: currentLocation) < $1.lastLocation!.distance(from: currentLocation)
            })
        } else {
            // If no devices have location, sort by signal strength
            closestDevice = devices.max(by: { ($0.rssi!) < ($1.rssi!) })
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        guard let deviceManager = deviceManager else { return }
        
        deviceManager.$devices
            .sink { [weak self] updatedDevices in
                guard let self = self else { return }
                self.devices = updatedDevices
                self.updateClosestDevice()
            }
            .store(in: &cancellables)
        
        deviceManager.$isScanning
            .sink { [weak self] isScanning in
                guard let self = self else { return }
                self.isScanning = isScanning
                
                if isScanning {
                    self.startRadarAnimation()
                } else {
                    self.stopRadarAnimation()
                }
            }
            .store(in: &cancellables)
        
        deviceManager.$errorMessage
            .sink { [weak self] errorMessage in
                self?.errorMessage = errorMessage
            }
            .store(in: &cancellables)
    }
    
    private func startRadarAnimation() {
        stopRadarAnimation() // Ensure no duplicate timers
        
        isAnimating = true
        
        // Create a timer that rotates the radar arm
        animationTimer = Timer.scheduledTimer(withTimeInterval: animationSpeed, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Rotate radar arm
            withAnimation {
                // Replace modulo operator with manual calculation
                let newAngle = self.radarAngle + 3
                self.radarAngle = newAngle >= 360 ? newAngle - 360 : newAngle
            }
        }
    }
    
    private func stopRadarAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        isAnimating = false
    }
    
    // Calculate distance description based on RSSI or actual location distance
    func distanceDescription(for device: Device) -> String {
        if let location = device.lastLocation, let userLocation = deviceManager?.locationService.currentLocation {
            let distance = location.distance(from: userLocation)
            
            if distance < 1 {
                return "Right here"
            } else if distance < 10 {
                return "Very close"
            } else if distance < 50 {
                return "Close by"
            } else if distance < 100 {
                return "Nearby"
            } else if distance < 1000 {
                return "\(Int(distance))m away"
            } else {
                return String(format: "%.1f km away", distance / 1000)
            }
        } else {
            // Calculate approximate distance using RSSI
            guard let rssi = device.rssi else {
                return "Unknown"
            }
            
            if rssi > -40 {
                return "Very close"
            } else if rssi > -60 {
                return "Close by"
            } else if rssi > -75 {
                return "Nearby"
            } else if rssi > -90 {
                return "Far away"
            } else {
                return "Very far"
            }
        }
    }
    
    // Calculate angle for device based on its position relative to user (simplified)
    func angleForDevice(_ device: Device) -> Double {
        // Cihazın görece açısını belirleyerek, radar üzerinde düzgün dağılımını sağlayalım
        // Gerçek konum verisi yoksa, ID tabanlı sabit bir açı oluşturalım
        let deviceIdString = device.id.uuidString
        let hashValue = abs(deviceIdString.hash)
        
        // Temel açı değeri (0-359 derece arasında)
        let baseAngle = Double(hashValue % 360)
        
        // RSSI değerine göre küçük varyasyon ekleyelim
        if let rssi = device.rssi {
            // rssi -30 ile -100 arasında değişebilir
            let rssiOffset = Double(min(-30, max(-100, rssi)) + 100) / 10.0
            return baseAngle + rssiOffset
        }
        
        return baseAngle
    }
    
    // Calculate normalized distance (0-1) for radar display
    func normalizedDistance(for device: Device) -> Double {
        // RSSI değerine göre normalize edilmiş mesafe (0.2 ile 0.9 arasında)
        if let rssi = device.rssi {
            // RSSI'ı -30 ile -100 arasında sınırlıyoruz
            let normalizedRSSI = min(-30, max(-100, rssi))
            
            // Mesafe hesaplama, -30 en yakın (0.2), -100 en uzak (0.9)
            let distance = 0.2 + (abs(Double(normalizedRSSI) + 30) / 70.0) * 0.7
            
            // İsme göre küçük bir ofset ekleyelim, böylece aynı RSSI'a sahip cihazlar üst üste gelmesin
            let nameLength = device.name.count
            let nameOffset = Double(nameLength % 10) / 100.0
            
            return distance + nameOffset
        }
        
        // Konum verisi yoksa, ID'ye göre tutarlı ama rastgele bir mesafe oluşturalım
        let hashVal = abs(device.id.uuidString.hash)
        return 0.3 + (Double(hashVal % 60) / 100.0)
    }
    
    // Calculate approximate distance based on RSSI
    func calculateDistance(rssi: Int?) -> Double {
        guard let rssi = rssi else { return 10.0 } // Default to 10 meters if no RSSI
        
        let txPower = -59 // RSSI at 1 meter (can be calibrated)
        let n = 2.5 // Path loss exponent (environment dependent)
        
        return pow(10, (Double(txPower - rssi) / (10 * n)))
    }
    
    // MARK: - Helper Methods
    // Generic cihaz isimlerini tanıma
    private func isGenericName(_ name: String) -> Bool {
        // Boş isimler veya çok kısa isimler
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count < 2 {
            return true
        }
        
        // Common generic device names patterns
        let genericPatterns = [
            "^LE-",
            "^BT",
            "^Unknown",
            "^Unnamed",
            "^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}$",
            "^[0-9]{2,}$", // Sadece rakamlardan oluşan isimler
            "[0-9A-F]{4,}", // MAC adresi bölümleri gibi görünen kısımlar
            "^[0-9A-Fa-f]{4,}$" // Hex kodlarından oluşan isimler
        ]
        
        // Check if the name matches any generic pattern
        for pattern in genericPatterns {
            if name.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Manufacturer-specific generic names
        let genericNames = [
            "Bluetooth",
            "Headset",
            "Speaker",
            "Mouse",
            "Keyboard",
            "Hands-Free",
            "HC-05", 
            "HC-06", 
            "ESP32", 
            "ESP8266",
            "JBL",
            "Mi",
            "EDIFIER",
            "3A13",
            "BLE"
        ]
        
        for genericName in genericNames {
            if name.contains(genericName) && name.count < 15 {
                return true
            }
        }
        
        return false
    }
} 
