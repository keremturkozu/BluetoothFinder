import Foundation
import CoreBluetooth
import Combine
import os.log

protocol BluetoothServiceDelegate: AnyObject {
    func didDiscoverDevice(peripheral: CBPeripheral?, rssi: NSNumber, advertisementData: [String: Any])
    func didConnectToDevice(_ peripheral: CBPeripheral)
    func didDisconnectFromDevice(_ peripheral: CBPeripheral, error: Error?)
    func didFailToConnect(_ peripheral: CBPeripheral, error: Error?)
    func didUpdateValueFor(characteristic: CBCharacteristic, peripheral: CBPeripheral)
    func bluetoothStateDidUpdate(isPoweredOn: Bool)
}

class BluetoothService: NSObject {
    // MARK: - Properties
    private let logger = Logger(subsystem: "com.nachz.BluetoothDeviceFinder", category: "BluetoothService")
    public let centralManager: CBCentralManager
    private var discoveredPeripherals = [CBPeripheral]()
    private var connectedPeripherals: [UUID: CBPeripheral] = [:]
    
    // Simulation mode properties
    private var simulationMode = false
    
    // Public simulation mode property
    var isSimulationModeEnabled: Bool {
        return simulationMode
    }
    
    // Flags
    private var scanning = false
    private var simulatorModeEnabled = false
    
    weak var delegate: BluetoothServiceDelegate?
    
    var isScanning: Bool {
        return centralManager.isScanning
    }
    
    var isPoweredOn: Bool {
        if simulationMode {
            return true
        }
        return centralManager.state == .poweredOn
    }
    
    // MARK: - Initialization
    override init() {
        centralManager = CBCentralManager(delegate: nil, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        super.init()
        centralManager.delegate = self
        
        // UserDefaults'tan simülasyon modunu oku (veya otomatik belirle)
        #if targetEnvironment(simulator)
        // Simülatörde her zaman simülasyon modu aktif olmalı
        simulationMode = true
        simulatorModeEnabled = true
        print("🔵 Running on simulator, automatically enabling simulator mode")
        #else
        // Gerçek cihazda UserDefaults'tan oku
        let simEnabled = UserDefaults.standard.bool(forKey: "SimulationModeEnabled")
        simulationMode = simEnabled
        simulatorModeEnabled = simEnabled
        print("🔵 Real device, simulation mode: \(simEnabled ? "enabled" : "disabled")")
        #endif
        
        print("🔵 BluetoothService initialized with state: \(centralManager.state.rawValue)")
    }
    
    // MARK: - Public Methods
    func startScanning() {
        guard !scanning else {
            print("🔵 Already scanning")
            return
        }
        
        print("🔵 Starting scan. Bluetooth powered on: \(isPoweredOn), Simulator mode: \(simulatorModeEnabled)")
        
        // If Bluetooth is powered on, scan for real devices
        if isPoweredOn && !simulationMode {
            print("🔵 Starting real device scan with specific services")
            
            // Apple Watch ve diğer Apple cihazları için servisler
            let serviceUUIDs: [CBUUID] = [
                // Genel Bluetooth servisleri
                CBUUID(string: "180F"),  // Battery Service
                CBUUID(string: "180A"),  // Device Information Service
                CBUUID(string: "1800"),  // Generic Access Service
                CBUUID(string: "1801"),  // Generic Attribute Service
                
                // Apple özel servisleri
                CBUUID(string: "D0611E78-BBB4-4591-A5F8-487910AE4366"), // Apple Continuity Service
                CBUUID(string: "9FA480E0-4967-4542-9390-D343DC5D04AE"), // Apple Nearby Service
                CBUUID(string: "7905F431-B5CE-4E99-A40F-4B1E122D00D0")  // Apple Media Service
            ]
            
            // Daha geniş bir tarama başlat (hem servis hem de özel servis olmayan cihazları bul)
            let options: [String: Any] = [
                CBCentralManagerScanOptionAllowDuplicatesKey: true,
                CBCentralManagerOptionShowPowerAlertKey: true
            ]
            
            // Önce servislerle tara, sonra hepsini tara
            centralManager.scanForPeripherals(withServices: serviceUUIDs, options: options)
            
            // Tüm cihazları da 1 saniye sonra taramaya başla
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.centralManager.scanForPeripherals(withServices: nil, options: options)
            }
            
            scanning = true
            logger.info("Started real device scanning for Apple and standard BLE devices")
        } else if simulationMode || simulatorModeEnabled {
            // If in simulator mode, start generating simulated devices
            print("🔵 Starting simulated scan")
            scanning = true
            createSimulatedDevices()
        } else {
            print("🔵 Cannot start scan - Bluetooth is not powered on and simulator mode is disabled")
        }
    }
    
    func stopScanning() {
        guard scanning else { return }
        
        if isPoweredOn {
            centralManager.stopScan()
        }
        
        scanning = false
        print("🔵 Scanning stopped")
    }
    
    func connect(to peripheral: CBPeripheral) {
        logger.debug("Connecting to \(peripheral.name ?? "Unknown Device")")
        
        // Eğer zaten bağlıysa ya da bağlanmaya çalışıyorsa, işlemi atla
        if peripheral.state == .connected {
            logger.debug("Already connected to \(peripheral.name ?? "Unknown Device")")
            delegate?.didConnectToDevice(peripheral)
            return
        }
        
        if peripheral.state == .connecting {
            logger.debug("Already trying to connect to \(peripheral.name ?? "Unknown Device")")
            return
        }
        
        // Önce peripheral'ı sınıfın delegate'i olarak ayarla
        peripheral.delegate = self
        
        // Bağlanmak için daha fazla seçenek ekle
        let connectionOptions: [String: Any] = [
            CBConnectPeripheralOptionNotifyOnConnectionKey: true,
            CBConnectPeripheralOptionNotifyOnDisconnectionKey: true,
            CBConnectPeripheralOptionNotifyOnNotificationKey: true
        ]
        
        logger.info("Starting connection to \(peripheral.name ?? "Unknown Device")")
        
        // Bağlantıyı başlat
        centralManager.connect(peripheral, options: connectionOptions)
        
        // Bağlantı zaman aşımı için bir timer ekleyelim
        DispatchQueue.main.asyncAfter(deadline: .now() + 15.0) { [weak self, weak peripheral] in
            guard let self = self, let peripheral = peripheral else { return }
            
            // Eğer hala connecting durumundaysa, bağlantıyı iptal et
            if peripheral.state == .connecting {
                self.logger.warning("Connection timeout for \(peripheral.name ?? "Unknown Device"), canceling")
                self.centralManager.cancelPeripheralConnection(peripheral)
                
                // Delegate'e bildir
                DispatchQueue.main.async {
                    self.delegate?.didFailToConnect(peripheral, error: NSError(domain: "com.nachz.BluetoothDeviceFinder", 
                                                                            code: -1, 
                                                                            userInfo: [NSLocalizedDescriptionKey: "Connection timeout"]))
                }
            }
        }
    }
    
    func disconnect(from peripheral: CBPeripheral) {
        logger.debug("Disconnecting from \(peripheral.name ?? "Unknown Device")")
        centralManager.cancelPeripheralConnection(peripheral)
    }
    
    func refreshRSSI(for peripheral: CBPeripheral) {
        if peripheral.state == .connected {
            peripheral.readRSSI()
        }
    }
    
    func readBatteryLevel(for peripheral: CBPeripheral) {
        // Simplified battery reading - find or discover battery service
        if peripheral.state != .connected {
            logger.warning("Cannot read battery level, device not connected")
            return
        }
        
        logger.debug("Reading battery level for \(peripheral.name ?? "Unknown Device")")
        
        // Önce servisler keşfedilmiş mi kontrol et
        if let services = peripheral.services {
            // Pil servisi var mı diye kontrol et
            if let batteryService = services.first(where: { $0.uuid == CBUUID(string: "180F") }) {
                // Pil servisi bulundu, karakteristikleri keşfet
                peripheral.discoverCharacteristics([CBUUID(string: "2A19")], for: batteryService)
            } else {
                // Pil servisi bulunamadı, tüm servisleri keşfet
                logger.debug("Battery service not found, discovering all services")
                discoverServices(for: peripheral)
            }
        } else {
            // Servisler keşfedilmemiş, önce servis keşfi başlat
            logger.debug("Services not discovered yet, discovering services first")
            discoverServices(for: peripheral)
        }
    }
    
    // Enable simulation mode for testing
    func enableSimulationMode() {
        #if targetEnvironment(simulator)
        simulationMode = true
        simulatorModeEnabled = true
        logger.info("Simulation mode manually enabled")
        #else
        // Gerçek cihazlarda simülasyon modunu etkinleştirmek tehlikelidir, log yazalım
        logger.warning("Attempt to enable simulation mode on real device - IGNORED")
        #endif
    }
    
    // MARK: - Simulation Methods
    private func createSimulatedDevices() {
        let devices = [
            ("iPhone", -45, "phone"),
            ("MacBook Pro", -55, "laptop"),
            ("AirPods Pro", -65, "headphones"),
            ("Apple Watch", -50, "watch"),
            ("Magic Mouse", -70, "mouse")
        ]
        
        // Create devices with delays to simulate discovery
        for (index, deviceInfo) in devices.enumerated() {
            let (name, rssi, type) = deviceInfo
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index + 1)) {
                self.addSimulatedDevice(name: name, rssi: rssi, type: type)
            }
        }
    }
    
    private func addSimulatedDevice(name: String, rssi: Int, type: String) {
        // Burada gerçek bir CBPeripheral oluşturamayız, bu yüzden simulasyon için delegate'e doğrudan bildirim yapıp
        // peripherals listesinde saklamayacağız
        let uuid = UUID()
        
        // Send to delegate with the UUID directly
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: name,
            "DeviceUUID": uuid,  // Özel bir alan ekleyelim
            "DeviceType": type   // Cihaz tipi için özel alan
        ]
        
        DispatchQueue.main.async {
            // Discover olayını delegate'e bildir ama peripheral olarak nil gönderme
            // RSSI ve advertisement data ile işlem yapılabilir
            if let delegate = self.delegate {
                // Burada peripheral nil olduğu için Device modelinde periperhal kullanmayan bir init kullanılması gerekir
                delegate.didDiscoverDevice(
                    peripheral: nil,
                    rssi: NSNumber(value: rssi), 
                    advertisementData: advertisementData
                )
            }
        }
        
        // Schedule RSSI updates
        startSimulatedRSSIUpdates(for: uuid, baseRSSI: rssi, name: name, type: type)
    }
    
    private func startSimulatedRSSIUpdates(for uuid: UUID, baseRSSI: Int, name: String, type: String) {
        var counter = 0
        Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            counter += 1
            if counter > 10 {
                timer.invalidate()
                return
            }
            
            // Random RSSI fluctuation
            let variation = Int.random(in: -5...5)
            let newRSSI = baseRSSI + variation
            
            DispatchQueue.main.async {
                // Simulasyon için peripheral nul gönderilir ve device manager UUID üzerinden eşleşme yapabilir
                let advertisementData: [String: Any] = [
                    CBAdvertisementDataLocalNameKey: name,
                    "DeviceUUID": uuid,
                    "DeviceType": type
                ]
                
                self.delegate?.didDiscoverDevice(
                    peripheral: nil,
                    rssi: NSNumber(value: newRSSI),
                    advertisementData: advertisementData
                )
            }
        }
    }
    
    // MARK: - Simulation Mode
    public func configureSimulatorMode(enabled: Bool) {
        simulatorModeEnabled = enabled
        if enabled {
            print("🔵 Simulator mode enabled")
            if scanning {
                print("🔵 Already scanning, generating simulated devices")
                createSimulatedDevices()
            }
        } else {
            print("🔵 Simulator mode disabled")
        }
    }
    
    // Cihaza bağlandığımızda servislerini keşfeden fonksiyon
    func discoverServices(for peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            logger.warning("Cannot discover services, device not connected")
            return
        }
        
        // Geniş bir servis aralığını keşfet (özellikle Apple cihazları için)
        // nil kullanarak tüm servisleri keşfetmek genellikle en iyi yaklaşımdır
        logger.debug("Discovering all services for \(peripheral.name ?? "Unknown Device")")
        peripheral.discoverServices(nil)
        
        // Ayrıca spesifik olarak bildiğimiz bazı servisleri de logla
        logger.debug("Looking for common services (Battery, Alert, Immediate Alert, Device Info)")
    }
    
    // Apple Watch'a ses çalma fonksiyonu (gerçek cihazlar için)
    func playSound(on peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            logger.warning("Cannot play sound, device not connected")
            return
        }
        
        logger.debug("Attempting to play sound on \(peripheral.name ?? "Unknown Device")")
        
        // Tüm servisleri keşfetmeyi dene
        if peripheral.services == nil || peripheral.services?.isEmpty == true {
            logger.debug("No services found, discovering services first")
            discoverServices(for: peripheral)
            
            // Servislerin keşfedilmesi için kısa bir süre bekle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.playSound(on: peripheral)
            }
            return
        }
        
        // Apple Media servisi için kontrol et
        if let services = peripheral.services {
            // Log all services for debugging
            logger.debug("Available services: \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")
            
            // Try standard alert notification service first
            if let alertService = services.first(where: { $0.uuid == CBUUID(string: "1811") }) { // Alert Notification Service
                peripheral.discoverCharacteristics(nil, for: alertService)
                logger.debug("Found alert service, discovering characteristics")
                
                if let characteristics = alertService.characteristics {
                    logger.debug("Alert service characteristics: \(characteristics.map { $0.uuid.uuidString }.joined(separator: ", "))")
                    
                    // Alert characteristics
                    if let alertCharacteristic = characteristics.first(where: { $0.uuid == CBUUID(string: "2A46") }) { // New Alert
                        // Ses çalma komutu gönder
                        let soundData = Data([0x00, 0x01]) // Category ID + Number of alerts
                        logger.debug("Writing to New Alert characteristic to play sound")
                        peripheral.writeValue(soundData, for: alertCharacteristic, type: .withResponse)
                        return
                    }
                } else {
                    // Karakteristikler keşfedilmemiş, keşfet
                    peripheral.discoverCharacteristics(nil, for: alertService)
                }
            }
            
            // Try Apple-specific media service as fallback
            if let mediaService = services.first(where: { $0.uuid == CBUUID(string: "7905F431-B5CE-4E99-A40F-4B1E122D00D0") }) {
                peripheral.discoverCharacteristics(nil, for: mediaService)
                logger.debug("Found Apple media service, discovering characteristics")
                
                // Ses çalma karakteristiğinin keşfi
                if let characteristics = mediaService.characteristics {
                    logger.debug("Media service characteristics: \(characteristics.map { $0.uuid.uuidString }.joined(separator: ", "))")
                    
                    // Karakteristik UUID'leri biliniyor olsaydı burada kullanılabilirdi
                    // Genellikle bu tür bilgilere erişim sınırlıdır, bu yüzden her karakteristiği deniyoruz
                    
                    // İlk bulunan yazılabilir karakteristiği kullan
                    if let writeableChar = characteristics.first(where: { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }) {
                        let playData = Data([0x01, 0x00]) // Örnek komut
                        logger.debug("Writing to media service characteristic to play sound")
                        peripheral.writeValue(playData, for: writeableChar, type: .withResponse)
                        return
                    }
                } else {
                    // Characteristics not discovered, discover them
                    peripheral.discoverCharacteristics(nil, for: mediaService)
                }
            }
            
            // Fallback: try immediate alert service (more widely supported)
            if let immediateAlertService = services.first(where: { $0.uuid == CBUUID(string: "1802") }) { // Immediate Alert Service
                peripheral.discoverCharacteristics([CBUUID(string: "2A06")], for: immediateAlertService) // Alert Level
                logger.debug("Found immediate alert service, trying to trigger alert")
                
                if let characteristics = immediateAlertService.characteristics, 
                   let alertLevelChar = characteristics.first(where: { $0.uuid == CBUUID(string: "2A06") }) {
                    // High alert level (0x02)
                    let highAlertData = Data([0x02])
                    logger.debug("Writing high alert level to trigger sound")
                    peripheral.writeValue(highAlertData, for: alertLevelChar, type: .withoutResponse)
                    return
                } else {
                    // Characteristics not discovered, discover them
                    peripheral.discoverCharacteristics([CBUUID(string: "2A06")], for: immediateAlertService)
                }
            }
        }
        
        logger.warning("No suitable service found for playing sound. Discovering all services...")
        peripheral.discoverServices(nil) // Discover all services as last resort
    }
    
    // Apple Watch'ta titreşim başlatma (gerçek cihazlar için)
    func vibrateDevice(on peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            logger.warning("Cannot vibrate device, not connected")
            return
        }
        
        logger.debug("Attempting to vibrate \(peripheral.name ?? "Unknown Device")")
        
        // Tüm servisleri keşfetmeyi dene
        if peripheral.services == nil || peripheral.services?.isEmpty == true {
            logger.debug("No services found, discovering services first")
            discoverServices(for: peripheral)
            
            // Servislerin keşfedilmesi için kısa bir süre bekle
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.vibrateDevice(on: peripheral)
            }
            return
        }
        
        // Mevcut servisleri kontrol et
        if let services = peripheral.services {
            // Hata ayıklama için tüm servisleri logla
            logger.debug("Available services for vibration: \(services.map { $0.uuid.uuidString }.joined(separator: ", "))")
            
            // Önce Immediate Alert Service'i dene (en yaygın desteklenen)
            if let immediateAlertService = services.first(where: { $0.uuid == CBUUID(string: "1802") }) {
                peripheral.discoverCharacteristics([CBUUID(string: "2A06")], for: immediateAlertService) // Alert Level
                logger.debug("Found immediate alert service, trying to trigger vibration")
                
                if let characteristics = immediateAlertService.characteristics, 
                   let alertLevelChar = characteristics.first(where: { $0.uuid == CBUUID(string: "2A06") }) {
                    // High alert level (0x02) to trigger vibration
                    let highAlertData = Data([0x02])
                    logger.debug("Writing high alert level to trigger vibration")
                    peripheral.writeValue(highAlertData, for: alertLevelChar, type: .withoutResponse)
                    return
                } else {
                    // Characteristics not discovered, discover them
                    peripheral.discoverCharacteristics([CBUUID(string: "2A06")], for: immediateAlertService)
                }
            }
            
            // Try standard alert notification service as fallback
            if let alertService = services.first(where: { $0.uuid == CBUUID(string: "1811") }) { // Alert Notification Service
                peripheral.discoverCharacteristics(nil, for: alertService)
                logger.debug("Found alert notification service, discovering characteristics")
                
                if let characteristics = alertService.characteristics {
                    logger.debug("Alert service characteristics: \(characteristics.map { $0.uuid.uuidString }.joined(separator: ", "))")
                    
                    // Try all potential alert characteristics
                    for characteristic in characteristics {
                        if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                            // Try to write vibration command
                            let alertData = Data([0x01]) // Simple alert command
                            logger.debug("Writing to alert characteristic: \(characteristic.uuid)")
                            peripheral.writeValue(alertData, for: characteristic, type: .withoutResponse)
                        }
                    }
                    return
                } else {
                    // Characteristics not discovered, discover them
                    peripheral.discoverCharacteristics(nil, for: alertService)
                }
            }
            
            // Last resort: try any service with writable characteristics
            for service in services {
                if let characteristics = service.characteristics {
                    // Log characteristics for this service
                    logger.debug("Service \(service.uuid) characteristics: \(characteristics.map { $0.uuid.uuidString }.joined(separator: ", "))")
                    
                    // Try to find any writable characteristic
                    if let writeableChar = characteristics.first(where: { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) }) {
                        let vibrateData = Data([0x01]) // Generic command
                        logger.debug("Writing to service \(service.uuid) characteristic \(writeableChar.uuid) as last resort")
                        peripheral.writeValue(vibrateData, for: writeableChar, type: .withoutResponse)
                        return
                    }
                } else {
                    // Keşfedilmemiş karakteristikler için keşfi başlat
                    peripheral.discoverCharacteristics(nil, for: service)
                }
            }
        }
        
        logger.warning("No suitable service found for vibration. Discovering all services...")
        peripheral.discoverServices(nil) // Discover all services as last resort
    }
    
    // MARK: - Apple Device Helper Methods
    
    // Apple cihazları için özel yöntemler
    func findAppleDevices() {
        // Apple cihazları için özel UUID'ler
        let appleProximityUUID = CBUUID(string: "74278BDA-B644-4520-8F0C-720EAF059935") // Örnek - gerçek UUID farklı olabilir
        let appleNearbyUUID = CBUUID(string: "9FA480E0-4967-4542-9390-D343DC5D04AE")
        
        logger.info("Scanning specifically for Apple devices")
        
        // Önce Apple'a özgü servisleri ara
        centralManager.scanForPeripherals(
            withServices: [appleProximityUUID, appleNearbyUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        )
        
        // Ardından genel taramayı da ekle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if !self.simulationMode && self.isPoweredOn {
                self.centralManager.scanForPeripherals(
                    withServices: nil,
                    options: [CBCentralManagerScanOptionAllowDuplicatesKey: true]
                )
            }
        }
    }
    
    // Apple Watch'un battery service'ini okumak için özel yöntem
    func readAppleWatchBattery(for peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            logger.warning("Cannot read Apple Watch battery: device not connected")
            return
        }
        
        // Apple Watch için kullanılabilecek bazı ek servisler
        let standardBatteryUUID = CBUUID(string: "180F") // Standart battery service
        let appleDeviceServiceUUID = CBUUID(string: "D0611E78-BBB4-4591-A5F8-487910AE4366") // Örnek Apple-özel servis
        
        // Önce standart servisi kontrol et, sonra Apple özel servislerini dene
        if let services = peripheral.services {
            logger.debug("Checking for battery services in Apple Watch")
            
            // Standart battery service'i kontrol et
            if let batteryService = services.first(where: { $0.uuid == standardBatteryUUID }) {
                peripheral.discoverCharacteristics([CBUUID(string: "2A19")], for: batteryService)
            } 
            // Apple özel servisleri kontrol et
            else if let appleService = services.first(where: { $0.uuid == appleDeviceServiceUUID }) {
                peripheral.discoverCharacteristics(nil, for: appleService)
                logger.debug("Discovered Apple-specific service, exploring characteristics")
            } 
            else {
                // Hiçbir bilinen servis bulunamadı, tüm servisleri keşfet
                logger.debug("No known battery services found, discovering all services")
                peripheral.discoverServices(nil)
            }
        } else {
            logger.debug("No services discovered yet, requesting all services for Apple Watch")
            peripheral.discoverServices(nil)
        }
    }
    
    // MARK: - RSSI Monitoring
    
    // Periyodik RSSI güncellemeleri için 
    private func startRSSIMonitoring(for peripheral: CBPeripheral) {
        guard peripheral.state == .connected else { 
            self.logger.warning("Cannot start RSSI monitoring: peripheral not connected")
            return 
        }
        
        self.logger.debug("Starting RSSI monitoring for \(peripheral.name ?? "Unknown Device")")
        
        // Timer'ı önce declare edip sonra initialize ediyoruz
        var timer: Timer?
        
        // Her 5 saniyede bir RSSI değerini güncelle, ama önce durumu kontrol et
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self, weak peripheral] _ in
            guard let self = self, 
                  let peripheral = peripheral,
                  peripheral.state == .connected else {
                // Timer'ı durdur çünkü cihaz bağlı değil
                self?.logger.debug("Stopping RSSI timer: peripheral disconnected or deallocated")
                timer?.invalidate()
                return
            }
            
            // Fazladan güvenlik kontrolü - yalnızca gerçekten bağlıysa RSSI oku
            if peripheral.state == .connected {
                self.logger.debug("Reading RSSI for \(peripheral.name ?? "Unknown")")
                peripheral.readRSSI()
            }
        }
        
        // Timer'ı mevcut run loop'a ekle
        if let validTimer = timer {
            RunLoop.current.add(validTimer, forMode: .common)
        }
    }
    
    // MARK: - Apple Watch Specific Functions
    
    // Apple Watch için özel ses çalma metodu
    func playSoundOnAppleWatch(peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            logger.warning("Cannot play sound on Apple Watch: device not connected")
            return
        }
        
        logger.debug("Attempting to play sound on Apple Watch: \(peripheral.name ?? "Unknown Watch")")
        
        // Apple Watch için yeni bir karakteristik kullanalım (Apple Watch için)
        let appleWatchAlertUUID = CBUUID(string: "1802") // Immediate Alert Service
        let alertLevelUUID = CBUUID(string: "2A06") // Alert Level
        
        // Servisleri keşfet (eğer henüz keşfedilmemişse)
        if peripheral.services == nil || peripheral.services?.isEmpty == true {
            logger.debug("No services found on Apple Watch, discovering services first")
            peripheral.discoverServices([appleWatchAlertUUID])
            
            // Kısa bir gecikme ile tekrar dene
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.playSoundOnAppleWatch(peripheral: peripheral)
            }
            return
        }
        
        // Immediate Alert servisi var mı kontrol et
        if let services = peripheral.services,
           let alertService = services.first(where: { $0.uuid == appleWatchAlertUUID }) {
            
            // Karakteristikleri keşfet (eğer henüz keşfedilmemişse)
            if alertService.characteristics == nil || alertService.characteristics?.isEmpty == true {
                logger.debug("Discovering alert characteristics for Apple Watch")
                peripheral.discoverCharacteristics([alertLevelUUID], for: alertService)
                
                // Kısa bir gecikme ile tekrar dene
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.playSoundOnAppleWatch(peripheral: peripheral)
                }
                return
            }
            
            // Alert Level karakteristiği var mı kontrol et
            if let characteristics = alertService.characteristics,
               let alertLevelChar = characteristics.first(where: { $0.uuid == alertLevelUUID }) {
                
                // Yüksek alert seviyesi (0x02) ile ses çalma
                let highAlertData = Data([0x02])
                logger.debug("Sending high alert level to Apple Watch to trigger sound")
                
                // WithoutResponse ile yazma (hızlı olması için)
                peripheral.writeValue(highAlertData, for: alertLevelChar, type: .withoutResponse)
                
                // 1 saniye sonra tekrar yazalım (daha güçlü uyarı için)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    peripheral.writeValue(highAlertData, for: alertLevelChar, type: .withoutResponse)
                    self.logger.debug("Second alert signal sent to Apple Watch")
                }
                
                return
            }
        }
        
        // Hala servisleri bulamadıysak, standart metodu çağıralım
        logger.debug("Could not find Apple Watch specific alert service, falling back to standard method")
        playSound(on: peripheral)
    }
    
    // Apple Watch için özel titreşim metodu
    func vibrateAppleWatch(peripheral: CBPeripheral) {
        guard peripheral.state == .connected else {
            logger.warning("Cannot vibrate Apple Watch: device not connected")
            return
        }
        
        logger.debug("Attempting to vibrate Apple Watch: \(peripheral.name ?? "Unknown Watch")")
        
        // Immediate Alert Service (Apple Watch'un titreşim için kullandığı servis)
        let immediateAlertUUID = CBUUID(string: "1802")
        let alertLevelUUID = CBUUID(string: "2A06")
        
        // Servisleri keşfet (eğer henüz keşfedilmemişse)
        if peripheral.services == nil || peripheral.services?.isEmpty == true {
            logger.debug("No services found on Apple Watch, discovering services first")
            peripheral.discoverServices([immediateAlertUUID])
            
            // Kısa bir gecikme ile tekrar dene
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.vibrateAppleWatch(peripheral: peripheral)
            }
            return
        }
        
        // Alert servisi var mı kontrol et
        if let services = peripheral.services,
           let alertService = services.first(where: { $0.uuid == immediateAlertUUID }) {
            
            // Karakteristikleri keşfet (eğer henüz keşfedilmemişse)
            if alertService.characteristics == nil || alertService.characteristics?.isEmpty == true {
                logger.debug("Discovering alert characteristics for Apple Watch vibration")
                peripheral.discoverCharacteristics([alertLevelUUID], for: alertService)
                
                // Kısa bir gecikme ile tekrar dene
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.vibrateAppleWatch(peripheral: peripheral)
                }
                return
            }
            
            // Alert Level karakteristiği var mı kontrol et
            if let characteristics = alertService.characteristics,
               let alertLevelChar = characteristics.first(where: { $0.uuid == alertLevelUUID }) {
                
                // En yüksek alert seviyesi (0x02) ile titreşim
                let highAlertData = Data([0x02])
                logger.debug("Sending high alert level to Apple Watch to trigger vibration")
                
                // WithoutResponse ile yazma (hızlı olması için)
                peripheral.writeValue(highAlertData, for: alertLevelChar, type: .withoutResponse)
                
                // 1.5 saniye sonra tekrar yazalım (sürekli titreşim için)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    peripheral.writeValue(highAlertData, for: alertLevelChar, type: .withoutResponse)
                    self.logger.debug("Second vibration signal sent to Apple Watch")
                }
                
                return
            }
        }
        
        // Hala servisleri bulamadıysak, standart metodu çağıralım
        logger.debug("Could not find Apple Watch specific alert service, falling back to standard method")
        vibrateDevice(on: peripheral)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothService: CBCentralManagerDelegate {
    public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print("🔵 Bluetooth state updated: \(central.state.rawValue)")
        
        let isOn = central.state == .poweredOn
        DispatchQueue.main.async {
            self.delegate?.bluetoothStateDidUpdate(isPoweredOn: isOn)
        }
        
        switch central.state {
        case .poweredOn:
            print("🔵 Bluetooth is powered on")
            if scanning {
                print("🔵 Restarting scan after power on")
                startScanning()
            }
        case .poweredOff:
            print("🔵 Bluetooth is powered off")
            scanning = false
        case .resetting:
            print("🔵 Bluetooth is resetting")
            scanning = false
        case .unauthorized:
            print("🔵 Bluetooth is unauthorized")
            scanning = false
        case .unsupported:
            print("🔵 Bluetooth is unsupported")
            scanning = false
            
            // If Bluetooth is unsupported (typically in simulator), enable simulator mode
            if !simulatorModeEnabled {
                configureSimulatorMode(enabled: true)
                if scanning {
                    print("🔵 Auto-enabling simulator mode due to unsupported Bluetooth")
                    createSimulatedDevices()
                }
            }
        case .unknown:
            print("🔵 Bluetooth state is unknown")
            scanning = false
        @unknown default:
            print("🔵 Bluetooth state unknown (default): \(central.state.rawValue)")
            scanning = false
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        print("🔵 Discovered peripheral: \(peripheral.identifier.uuidString) (\(peripheral.name ?? "Unnamed"))")
        
        // Store the peripheral
        if !discoveredPeripherals.contains(peripheral) {
            discoveredPeripherals.append(peripheral)
        }
        
        // Notify delegate
        delegate?.didDiscoverDevice(peripheral: peripheral, rssi: RSSI, advertisementData: advertisementData)
    }
    
    public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("🔵 Connected to peripheral: \(peripheral.identifier.uuidString) (\(peripheral.name ?? "Unnamed"))")
        logger.info("Successfully connected to \(peripheral.name ?? "Unknown Device")")
        
        // Bağlandığımız cihazı kaydet
        connectedPeripherals[peripheral.identifier] = peripheral
        
        // Peripheral delegate'ini ayarla (bağlandıktan hemen sonra)
        peripheral.delegate = self
        
        // İlk önce delegate'e bağlantının tamamlandığını bildir
        DispatchQueue.main.async {
            self.delegate?.didConnectToDevice(peripheral)
        }
        
        // Kullanıcı arayüzünün güncellenmesi için kısa bir gecikme ver
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak peripheral] in
            guard let self = self, let peripheral = peripheral, peripheral.state == .connected else { return }
            
            // İlk servis keşfi yapılırken, peripheral'ın bağlı olduğundan emin ol
            if peripheral.state == .connected {
                logger.debug("Starting service discovery after successful connection")
                self.discoverServices(for: peripheral)
                
                // RSSI değerlerini okumaya biraz daha geç başla (servisleri keşfetmek öncelikli)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self, weak peripheral] in
                    guard let self = self, let peripheral = peripheral, peripheral.state == .connected else { return }
                    
                    // RSSI izleme başlat
                    self.startRSSIMonitoring(for: peripheral)
                }
            }
        }
    }
    
    public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        if let error = error {
            print("🔵 Disconnected from peripheral with error: \(error.localizedDescription)")
        } else {
            print("🔵 Disconnected from peripheral: \(peripheral.identifier.uuidString) (\(peripheral.name ?? "Unnamed"))")
        }
        connectedPeripherals.removeValue(forKey: peripheral.identifier)
        delegate?.didDisconnectFromDevice(peripheral, error: error)
    }
    
    public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("🔵 Failed to connect to peripheral: \(peripheral.identifier.uuidString) (\(peripheral.name ?? "Unnamed")). Error: \(error?.localizedDescription ?? "No error")")
        delegate?.didFailToConnect(peripheral, error: error)
    }
    
    func centralManager(_ central: CBCentralManager, willRestoreState dict: [String : Any]) {
        logger.debug("Restoring central manager state")
        
        // Restore connected peripherals
        if let peripherals = dict[CBCentralManagerRestoredStatePeripheralsKey] as? [CBPeripheral] {
            for peripheral in peripherals {
                logger.debug("Restoring peripheral: \(peripheral.name ?? "Unknown Device")")
                peripheral.delegate = self
                connectedPeripherals[peripheral.identifier] = peripheral
                
                if peripheral.state == .connected {
                    DispatchQueue.main.async {
                        self.delegate?.didConnectToDevice(peripheral)
                    }
                }
            }
        }
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothService: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else { 
            if let error = error {
                logger.error("Error discovering services: \(error.localizedDescription)")
            }
            return 
        }
        
        for service in services {
            logger.debug("Discovered service: \(service.uuid)")
            
            // Discover characteristics for battery service
            if service.uuid == CBUUID(string: "180F") {
                peripheral.discoverCharacteristics([CBUUID(string: "2A19")], for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard error == nil, let characteristics = service.characteristics else { 
            if let error = error {
                logger.error("Error discovering characteristics: \(error.localizedDescription)")
            }
            return 
        }
        
        logger.debug("Service \(service.uuid.uuidString) has \(characteristics.count) characteristics:")
        for characteristic in characteristics {
            logger.debug("   Found characteristic: \(characteristic.uuid.uuidString), properties: \(characteristic.properties.rawValue)")
            
            // Battery level characteristic
            if characteristic.uuid == CBUUID(string: "2A19") {
                logger.debug("🔋 Found battery level characteristic, reading value")
                peripheral.readValue(for: characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
            
            // Bu characteristic'in okunabilir olduğunu kontrol et
            if characteristic.properties.contains(.read) {
                logger.debug("Reading value for characteristic: \(characteristic.uuid.uuidString)")
                peripheral.readValue(for: characteristic)
            }
            
            // Notification destekliyorsa, bildirim için abone ol
            if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                logger.debug("Subscribing to notifications for: \(characteristic.uuid.uuidString)")
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            logger.error("Error updating value for \(characteristic.uuid.uuidString): \(error.localizedDescription)")
            return 
        }
        
        // Log the received data
        if let data = characteristic.value {
            logger.debug("Received data for \(characteristic.uuid.uuidString): \(data.map { String(format: "%02x", $0) }.joined())")
            
            // Battery level specific handling (0x2A19)
            if characteristic.uuid == CBUUID(string: "2A19") && data.count > 0 {
                let batteryLevel = Int(data[0])
                logger.debug("🔋 Battery level for \(peripheral.name ?? "Unknown"): \(batteryLevel)%")
                
                // Önemli: Pil seviyesi güncelleme işlemi
                DispatchQueue.main.async {
                    self.delegate?.didUpdateValueFor(characteristic: characteristic, peripheral: peripheral)
                }
            }
        } else {
            logger.debug("Received empty data for \(characteristic.uuid.uuidString)")
        }
        
        // Always notify delegate about value updates
        DispatchQueue.main.async {
            self.delegate?.didUpdateValueFor(characteristic: characteristic, peripheral: peripheral)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didReadRSSI RSSI: NSNumber, error: Error?) {
        // Hata durumunu daha iyi ele al
        if let error = error { 
            logger.error("Error reading RSSI for \(peripheral.name ?? "Unknown"): \(error.localizedDescription)")
            
            // Cihaz bağlantısı kesildiyse, RSSI güncellemesini atlayalım
            if peripheral.state != .connected {
                logger.warning("Peripheral disconnected during RSSI reading, ignoring update")
                return
            }
            
            return 
        }
        
        logger.debug("Successfully updated RSSI for \(peripheral.name ?? "Unknown"): \(RSSI)")
        
        // Sadece hata yoksa ve cihaz hala bağlıysa, RSSI güncelleyin
        if peripheral.state == .connected {
            DispatchQueue.main.async {
                self.delegate?.didDiscoverDevice(peripheral: peripheral, rssi: RSSI, advertisementData: [:])
            }
        }
    }
} 
