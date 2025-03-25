import Foundation
import MapKit

class DeviceAnnotation: Identifiable {
    let id: UUID
    let device: Device?
    
    var coordinate: CLLocationCoordinate2D {
        return device?.location?.coordinate ?? CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    init(device: Device?) {
        self.device = device
        self.id = device?.id ?? UUID()
    }
} 