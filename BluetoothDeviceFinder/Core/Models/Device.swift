import Foundation
import CoreLocation
import CoreBluetooth
import Combine

// Signal strength enum (used to determine proximity)
enum SignalStrength: String {
    case excellent
    case good
    case fair
    case poor
    
    var description: String {
        switch self {
        case .excellent: return "Very Close"
        case .good: return "Close"
        case .fair: return "Nearby"
        case .poor: return "Far Away"
        }
    }
    
    var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .fair: return "orange"
        case .poor: return "red"
        }
    }
    
    // Convert RSSI to signal strength category
    static func fromRSSI(_ rssi: Int?) -> SignalStrength {
        let validRssi = rssi ?? -100
        switch validRssi {
        case -60...0: return .excellent
        case -70...(-61): return .good
        case -80...(-71): return .fair
        default: return .poor
        }
    }
}

// Device types for more specific UI
enum DeviceType: String, Codable, CaseIterable {
    case headphones
    case speaker
    case watch
    case phone
    case tablet
    case laptop
    case computer
    case keyboard
    case mouse
    case unknown
    
    var icon: String {
        switch self {
        case .headphones: return "headphones"
        case .speaker: return "hifispeaker"
        case .watch: return "applewatch"
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .computer: return "desktopcomputer"
        case .keyboard: return "keyboard"
        case .mouse: return "magicmouse"
        case .unknown: return "questionmark.circle"
        }
    }
}

// Main Device model
class Device: Identifiable, Codable, ObservableObject {
    // Core properties
    let id: UUID
    @Published var name: String
    @Published var rssi: Int?
    @Published var type: DeviceType
    @Published var lastSeen: Date?
    
    // Optional properties
    @Published var batteryLevel: Int?
    @Published var isConnected: Bool = false
    @Published var isSaved: Bool = false
    
    // Location properties
    @Published var latitude: Double?
    @Published var longitude: Double?
    var lastLocation: CLLocation? {
        if let lat = latitude, let lon = longitude {
            return CLLocation(latitude: lat, longitude: lon)
        }
        return nil
    }
    
    // Not stored in Codable
    var peripheral: CBPeripheral?
    
    // MARK: - Computed Properties
    
    var signalStrength: SignalStrength {
        return SignalStrength.fromRSSI(rssi)
    }
    
    var proximity: String {
        return signalStrength.description
    }
    
    // MARK: - Initialization
    
    init(id: UUID, peripheral: CBPeripheral? = nil, name: String, rssi: Int? = nil, batteryLevel: Int? = nil, isConnected: Bool = false, lastSeen: Date? = nil, type: DeviceType = .unknown) {
        self.id = id
        self.peripheral = peripheral
        self.name = name
        self.rssi = rssi
        self.batteryLevel = batteryLevel
        self.isConnected = isConnected
        self.lastSeen = lastSeen
        self.type = type
    }
    
    // MARK: - Methods
    
    func updateLocation(_ location: CLLocation) {
        self.latitude = location.coordinate.latitude
        self.longitude = location.coordinate.longitude
    }
    
    // MARK: - Codable
    
    enum CodingKeys: String, CodingKey {
        case id, name, rssi, type, lastSeen, batteryLevel, isConnected, isSaved, latitude, longitude
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        rssi = try container.decodeIfPresent(Int.self, forKey: .rssi)
        type = try container.decode(DeviceType.self, forKey: .type)
        lastSeen = try container.decodeIfPresent(Date.self, forKey: .lastSeen)
        batteryLevel = try container.decodeIfPresent(Int.self, forKey: .batteryLevel)
        isConnected = try container.decodeIfPresent(Bool.self, forKey: .isConnected) ?? false
        isSaved = try container.decodeIfPresent(Bool.self, forKey: .isSaved) ?? false
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(rssi, forKey: .rssi)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(lastSeen, forKey: .lastSeen)
        try container.encodeIfPresent(batteryLevel, forKey: .batteryLevel)
        try container.encode(isConnected, forKey: .isConnected)
        try container.encode(isSaved, forKey: .isSaved)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
    }
}

// MARK: - Hashable & Equatable
extension Device: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Device, rhs: Device) -> Bool {
        return lhs.id == rhs.id
    }
} 