import SwiftUI

@main
struct BluetoothDeviceFinderApp: App {
    // App genelinde tek bir DeviceManager nesnesi kullanalım
    @StateObject private var deviceManager = DeviceManager()
    
    init() {
        // Simülasyon modunu gerçek cihazlarda tamamen kapatalım
        #if targetEnvironment(simulator)
        // Simülatörde Bluetooth gerçekten çalışmaz, simülasyon modu gereklidir
        print("📱 Simulator detected, activating simulation mode")
        UserDefaults.standard.set(true, forKey: "SimulationModeEnabled")
        #else
        // Gerçek cihazlarda her zaman simülasyon modunu kapatalım
        print("📱 Real device detected, DISABLING simulation mode")
        UserDefaults.standard.set(false, forKey: "SimulationModeEnabled")
        #endif
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deviceManager)
                .onAppear {
                    #if targetEnvironment(simulator)
                    // Simülatörde simülasyon modunu aktifleştir
                    deviceManager.bluetoothService.enableSimulationMode()
                    #endif
                    
                    // Uygulama başlatıldığında otomatik olarak taramayı başlat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        deviceManager.startScanning()
                    }
                }
        }
    }
} 