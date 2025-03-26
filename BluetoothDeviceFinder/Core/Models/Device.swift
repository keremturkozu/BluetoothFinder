import Foundation
import CoreLocation
import CoreBluetooth

enum DeviceType: String, Codable {
    case headphones
    case speaker
    case watch
    case keyboard
    case mouse
    case phone
    case tablet
    case laptop
    case computer
    case unknown
}

class Device: Identifiable, ObservableObject, Codable {
    let id: UUID
    let peripheral: CBPeripheral?
    @Published var name: String
    @Published var rssi: Int?
    @Published var location: CLLocation?
    @Published var batteryLevel: Int?
    @Published var isConnected: Bool
    @Published var isSaved: Bool
    @Published var lastSeen: Date
    @Published var type: DeviceType
    @Published var advertisementData: [String: Any]?
    
    init(id: UUID = UUID(), 
         peripheral: CBPeripheral? = nil,
         name: String, 
         rssi: Int? = nil, 
         location: CLLocation? = nil, 
         batteryLevel: Int? = nil, 
         isConnected: Bool = false, 
         isSaved: Bool = false,
         lastSeen: Date = Date(),
         type: DeviceType = .unknown,
         advertisementData: [String: Any]? = nil) {
        self.id = id
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
        self.location = location
        self.batteryLevel = batteryLevel
        self.isConnected = isConnected
        self.isSaved = isSaved
        self.lastSeen = lastSeen
        self.type = type
        self.advertisementData = advertisementData
    }
    
    // MARK: - Codable Implementation
    private enum CodingKeys: String, CodingKey {
        case id, name, rssi, location, batteryLevel, isConnected, isSaved, lastSeen, type
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        peripheral = nil
        name = try container.decode(String.self, forKey: .name)
        rssi = try container.decodeIfPresent(Int.self, forKey: .rssi)
        
        // Decode location if present
        if let locationData = try container.decodeIfPresent(LocationData.self, forKey: .location) {
            location = CLLocation(
                coordinate: CLLocationCoordinate2D(
                    latitude: locationData.latitude,
                    longitude: locationData.longitude
                ),
                altitude: locationData.altitude,
                horizontalAccuracy: locationData.horizontalAccuracy,
                verticalAccuracy: locationData.verticalAccuracy,
                timestamp: locationData.timestamp
            )
        } else {
            location = nil
        }
        
        batteryLevel = try container.decodeIfPresent(Int.self, forKey: .batteryLevel)
        isConnected = try container.decode(Bool.self, forKey: .isConnected)
        isSaved = try container.decode(Bool.self, forKey: .isSaved)
        lastSeen = try container.decode(Date.self, forKey: .lastSeen)
        type = try container.decode(DeviceType.self, forKey: .type)
        advertisementData = nil
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(rssi, forKey: .rssi)
        
        // Encode location if present
        if let locationValue = location {
            let locationData = LocationData(
                latitude: locationValue.coordinate.latitude,
                longitude: locationValue.coordinate.longitude,
                altitude: locationValue.altitude,
                horizontalAccuracy: locationValue.horizontalAccuracy,
                verticalAccuracy: locationValue.verticalAccuracy,
                timestamp: locationValue.timestamp
            )
            try container.encode(locationData, forKey: .location)
        }
        
        try container.encode(batteryLevel, forKey: .batteryLevel)
        try container.encode(isConnected, forKey: .isConnected)
        try container.encode(isSaved, forKey: .isSaved)
        try container.encode(lastSeen, forKey: .lastSeen)
        try container.encode(type, forKey: .type)
    }
    
    // MARK: - Helper Structs for Codable
    private struct LocationData: Codable {
        let latitude: Double
        let longitude: Double
        let altitude: Double
        let horizontalAccuracy: Double
        let verticalAccuracy: Double
        let timestamp: Date
    }
    
    // MARK: - Helper Properties
    var signalStrength: SignalStrength {
        guard let rssi = rssi else { return .unknown }
        
        if rssi > -50 {
            return .excellent
        } else if rssi > -65 {
            return .good
        } else if rssi > -80 {
            return .fair
        } else {
            return .poor
        }
    }
    
    var distanceDescription: String? {
        guard let rssi = rssi else { return nil }
        
        switch signalStrength {
        case .excellent:
            return "Very close"
        case .good:
            return "Close"
        case .fair:
            return "Nearby"
        case .poor:
            return "Far away"
        case .unknown:
            return nil
        }
    }
    
    // MARK: - Helper Methods
    func update(with peripheral: CBPeripheral, rssi: Int, advertisementData: [String: Any]) {
        self.name = peripheral.name ?? "Unknown Device"
        self.rssi = rssi
        self.lastSeen = Date()
        self.advertisementData = advertisementData
        
        // Her zaman cihaz türünü tekrar tespit et ve güncelle
        let updatedType = detectDeviceType(advertisementData: advertisementData)
        if updatedType != .unknown {
            self.type = updatedType
        }
    }
    
    func updateLocation(_ newLocation: CLLocation) {
        self.location = newLocation
    }
    
    private func detectDeviceType(advertisementData: [String: Any]) -> DeviceType {
        // Servis UUIDlerine bak
        if let serviceUUIDs = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] {
            // Headphones ve Audio cihazlar için A2DP servisi
            if serviceUUIDs.contains(where: { $0.uuidString.contains("110A") || $0.uuidString.contains("110B") }) {
                return .headphones
            }
            
            // Apple Watch ve akıllı saatler
            if serviceUUIDs.contains(where: { $0.uuidString.contains("1801") || $0.uuidString.contains("1805") }) {
                return .watch
            }
            
            // Klavye ve Mouse (HID Servisi)
            if serviceUUIDs.contains(where: { $0.uuidString.contains("1812") }) {
                // İsme bakarak klavye mi fare mi belirleyelim
                let lowercaseName = name.lowercased()
                if lowercaseName.contains("mouse") {
                    return .mouse
                } else {
                    return .keyboard
                }
            }
        }
        
        // Determine device type from name if we couldn't from services
        let lowercaseName = name.lowercased()
        if lowercaseName.contains("headphone") || lowercaseName.contains("airpod") || lowercaseName.contains("earbud") || lowercaseName.contains("headset") {
            return .headphones
        } else if lowercaseName.contains("speaker") || lowercaseName.contains("sound") || lowercaseName.contains("audio") {
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
        } else if lowercaseName.contains("mac") || lowercaseName.contains("book") || lowercaseName.contains("laptop") {
            return .laptop
        } else if lowercaseName.contains("computer") {
            return .computer
        }
        
        // Apple ürünleri için üretici verisine bak
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data, 
           manufacturerData.count >= 2 {
            // Apple'ın üretici ID'si 0x004C'dir
            let manufacturerID = UInt16(manufacturerData[0]) + (UInt16(manufacturerData[1]) << 8)
            if manufacturerID == 0x004C {
                // Bu bir Apple ürünü, ama hangisi olduğunu bilemiyoruz
                // AirPods genellikle özel bir hizmet sunar, zaten yukarıda kontrol ettik
                if lowercaseName.contains("airpod") {
                    return .headphones
                } else if lowercaseName.contains("watch") {
                    return .watch
                } else {
                    // Varsayılan olarak telefon diyelim
                    return .phone
                }
            }
        }
        
        return .unknown
    }
}

// MARK: - Enums
enum SignalStrength: String {
    case excellent
    case good
    case fair
    case poor
    case unknown
}

// MARK: - Hashable & Equatable
extension Device: Hashable {
    static func == (lhs: Device, rhs: Device) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
} 