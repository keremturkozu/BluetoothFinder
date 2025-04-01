import Foundation
import MapKit
import Combine
import CoreLocation

class DeviceMapViewModel: ObservableObject {
    @Published var mapAnnotations: [DeviceAnnotation] = []
    @Published var selectedDevice: Device?
    @Published var hideUnnamedDevices: Bool = false
    
    private var deviceManager: DeviceManager?
    
    // Filtrelenmiş cihazları hesaplayan computed property
    var filteredAnnotations: [DeviceAnnotation] {
        if hideUnnamedDevices {
            return mapAnnotations.filter { !isGenericName($0.device.name) }
        } else {
            return mapAnnotations
        }
    }
    
    func injectDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
    }
    
    func updateAnnotations(from devices: [Device]) {
        mapAnnotations = devices.compactMap { device in
            if let _ = device.lastLocation {
                return DeviceAnnotation(device: device)
            }
            return nil
        }
    }
    
    func selectDevice(_ device: Device) {
        selectedDevice = device
    }
    
    func saveDeviceUpdate(_ device: Device) {
        guard let deviceManager = deviceManager else { return }
        deviceManager.updateDevice(device)
    }
    
    func distanceText(for device: Device) -> String {
        guard let deviceManager = deviceManager,
              let userLocation = deviceManager.locationService.currentLocation,
              let deviceLocation = device.lastLocation else {
            return "Unknown distance"
        }
        
        let distance = userLocation.distance(from: deviceLocation)
        
        // Format based on distance
        if distance < 1000 {
            return String(format: "%.0f m away", distance)
        } else {
            return String(format: "%.1f km away", distance / 1000)
        }
    }
    
    // Generic cihaz isimlerini tanıma
    private func isGenericName(_ name: String) -> Bool {
        // Common generic device names patterns
        let genericPatterns = [
            "^LE-",
            "^BT",
            "^Unknown",
            "^Unnamed",
            "^[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}:[0-9A-F]{2}$"
        ]
        
        // Check if the name matches any generic pattern
        for pattern in genericPatterns {
            if name.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
} 