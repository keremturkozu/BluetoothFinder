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
    
    // MARK: - Private Properties
    private var deviceManager: DeviceManager?
    private var cancellables = Set<AnyCancellable>()
    private var animationTimer: Timer?
    private let animationSpeed: Double = 0.05 // Radar rotation speed
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Dependency Injection
    func injectDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
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
        let devicesWithLocation = devices.filter { $0.location != nil }
        
        if !devicesWithLocation.isEmpty {
            closestDevice = devicesWithLocation.min(by: { 
                $0.location!.distance(from: currentLocation) < $1.location!.distance(from: currentLocation)
            })
        } else {
            // If no devices have location, sort by signal strength
            closestDevice = devices.max(by: { ($0.rssi ?? -100) < ($1.rssi ?? -100) })
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
        if let location = device.location, let userLocation = deviceManager?.locationService.currentLocation {
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
        } else if let rssi = device.rssi {
            // Calculate approximate distance using RSSI
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
        
        return "Unknown distance"
    }
    
    // Calculate angle for device based on its position relative to user (simplified)
    func angleForDevice(_ device: Device) -> Double {
        guard let location = device.location, 
              let userLocation = deviceManager?.locationService.currentLocation else {
            // If no location data, use device ID to give a consistent but random angle
            // This will distribute devices around the entire radar circle
            let deviceIdString = device.id.uuidString
            let hashValue = abs(deviceIdString.hash)
            return Double(hashValue % 360)
        }
        
        // Calculate actual angle based on GPS coordinates
        let deltaLong = location.coordinate.longitude - userLocation.coordinate.longitude
        let deltaLat = location.coordinate.latitude - userLocation.coordinate.latitude
        
        // Calculate angle in radians
        let angleRadians = atan2(deltaLong, deltaLat)
        
        // Convert to degrees and ensure positive values (0-360)
        var angleDegrees = angleRadians * 180 / .pi
        
        // Adjust for SwiftUI coordinate system
        while angleDegrees < 0 {
            angleDegrees += 360
        }
        while angleDegrees >= 360 {
            angleDegrees -= 360
        }
        
        return angleDegrees
    }
    
    // Calculate normalized distance (0-1) for radar display
    func normalizedDistance(for device: Device) -> Double {
        if let location = device.location, let userLocation = deviceManager?.locationService.currentLocation {
            let distance = location.distance(from: userLocation)
            // Normalize to 0-1 with max effective range of 1km
            return min(0.9, max(0.1, distance / 1000))
        } else if let rssi = device.rssi {
            // Convert RSSI to a normalized distance
            // -40 is very close (0.1), -90 is far (0.9)
            let normalized = (abs(Double(rssi)) - 40) / 50
            return min(0.9, max(0.1, normalized))
        }
        
        // Default value when no data available - place in middle range
        return Double.random(in: 0.3...0.7)
    }
    
    // Calculate approximate distance based on RSSI
    func calculateDistance(rssi: Int?) -> Double {
        guard let rssi = rssi else { return 10.0 } // Default to 10 meters if no RSSI
        
        let txPower = -59 // RSSI at 1 meter (can be calibrated)
        let n = 2.5 // Path loss exponent (environment dependent)
        
        return pow(10, (Double(txPower - rssi) / (10 * n)))
    }
} 