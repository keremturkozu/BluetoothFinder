import Foundation
import MapKit

class DeviceAnnotation: NSObject, MKAnnotation, Identifiable {
    let device: Device
    var id: UUID { device.id }
    
    var coordinate: CLLocationCoordinate2D {
        if let location = device.lastLocation {
            return location.coordinate
        }
        return CLLocationCoordinate2D(latitude: 0, longitude: 0)
    }
    
    var title: String? {
        return device.name
    }
    
    var subtitle: String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        
        if let lastSeen = device.lastSeen {
            return "Last seen: \(dateFormatter.string(from: lastSeen))"
        } else {
            return "Unknown last seen time"
        }
    }
    
    init(device: Device) {
        self.device = device
        super.init()
    }
} 