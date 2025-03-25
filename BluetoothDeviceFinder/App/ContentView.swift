import SwiftUI

enum Tab: Int {
    case devices
    case map
    case radar
    case saved
    case settings
}

struct ContentView: View {
    @StateObject private var deviceManager = DeviceManager()
    @State private var selectedTab: Tab = .devices
    @AppStorage("darkMode") private var darkMode = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Devices List Tab
            DeviceListView()
                .tabItem {
                    Label("Devices", systemImage: "antenna.radiowaves.left.and.right")
                }
                .tag(Tab.devices)
            
            // Device Map Tab
            DeviceMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
                .tag(Tab.map)
            
            // Radar Tab
            RadarView(viewModel: RadarViewModel())
                .tabItem {
                    Label("Radar", systemImage: "scope")
                }
                .tag(Tab.radar)
            
            // Saved Devices Tab
            SavedDevicesView()
                .tabItem {
                    Label("Saved", systemImage: "star")
                }
                .tag(Tab.saved)
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .environmentObject(deviceManager)
        .onAppear {
            // Request location permission when app starts
            deviceManager.locationService.requestAuthorization()
            
            // Apply the dark mode setting when app starts
            setAppAppearance(darkMode: darkMode)
        }
        .onChange(of: darkMode) { newValue in
            setAppAppearance(darkMode: newValue)
        }
        .preferredColorScheme(darkMode ? .dark : .light)
    }
    
    private func setAppAppearance(darkMode: Bool) {
        // Set system-wide appearance
        let scenes = UIApplication.shared.connectedScenes
        let windowScene = scenes.first as? UIWindowScene
        let windows = windowScene?.windows
        
        windows?.forEach { window in
            window.overrideUserInterfaceStyle = darkMode ? .dark : .light
        }
    }
}

#Preview {
    ContentView()
} 