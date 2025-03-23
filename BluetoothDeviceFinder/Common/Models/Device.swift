import Foundation
import CoreLocation

struct Device: Identifiable {
    let id: UUID
    let name: String
    let identifier: String
    var location: CLLocation?
    var lastSeen: Date
    var batteryLevel: Int?
    var rssi: Int?
    var isConnected: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        identifier: String,
        location: CLLocation? = nil,
        lastSeen: Date = Date(),
        batteryLevel: Int? = nil,
        rssi: Int? = nil,
        isConnected: Bool = false
    ) {
        self.id = id
        self.name = name
        self.identifier = identifier
        self.location = location
        self.lastSeen = lastSeen
        self.batteryLevel = batteryLevel
        self.rssi = rssi
        self.isConnected = isConnected
    }
}

extension Device {
    var distanceDescription: String? {
        guard let rssi = rssi else { return nil }
        
        if rssi > -50 {
            return "Very close"
        } else if rssi > -65 {
            return "Close"
        } else if rssi > -80 {
            return "Nearby"
        } else {
            return "Far"
        }
    }
    
    var batteryDescription: String {
        guard let batteryLevel = batteryLevel else { return "Unknown" }
        return "\(batteryLevel)%"
    }
} 