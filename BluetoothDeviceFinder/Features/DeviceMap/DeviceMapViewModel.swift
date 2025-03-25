import Foundation
import MapKit
import Combine
import CoreLocation

class DeviceMapViewModel: ObservableObject {
    @Published var mapAnnotations: [DeviceAnnotation] = []
    @Published var selectedDevice: Device?
    
    private var deviceManager: DeviceManager?
    
    func injectDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
    }
    
    func updateAnnotations(from devices: [Device]) {
        mapAnnotations = devices.compactMap { device in
            if let _ = device.location {
                return DeviceAnnotation(device: device)
            }
            return nil
        }
    }
    
    func selectDevice(_ device: Device) {
        selectedDevice = device
    }
    
    func updateDevice(_ device: Device) {
        guard let deviceManager = deviceManager else { return }
        deviceManager.updateDevice(device)
    }
    
    func distanceText(for device: Device) -> String {
        guard let deviceManager = deviceManager,
              let userLocation = deviceManager.locationService.currentLocation,
              let deviceLocation = device.location else {
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
} 