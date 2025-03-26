import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @Environment(\.dismiss) private var dismiss
    @State private var showLocationPermissionAlert = false
    @State private var showBluetoothPermissionAlert = false
    @State private var showNotificationPermissionAlert = false
    
    @AppStorage("distanceUnit") private var distanceUnit = "meters"
    @AppStorage("keepScreenOn") private var keepScreenOn = true
    @AppStorage("saveLastLocation") private var saveLastLocation = true
    @AppStorage("darkMode") private var darkMode = false
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Permissions")) {
                    permissionButton(
                        title: "Location",
                        systemImage: "location.fill",
                        authorized: deviceManager.locationService.authorizationStatus == .authorizedWhenInUse || deviceManager.locationService.authorizationStatus == .authorizedAlways,
                        action: {
                            if deviceManager.locationService.authorizationStatus == .denied {
                                showLocationPermissionAlert = true
                            } else {
                                deviceManager.locationService.requestAuthorization()
                            }
                        }
                    )
                    
                    permissionButton(
                        title: "Bluetooth",
                        systemImage: "antenna.radiowaves.left.and.right",
                        authorized: deviceManager.bluetoothService.isPoweredOn,
                        action: { 
                            showBluetoothPermissionAlert = true
                        }
                    )
                    
                    permissionButton(
                        title: "Notifications",
                        systemImage: "bell.fill",
                        authorized: true, // We would check this with UNUserNotificationCenter
                        action: {
                            showNotificationPermissionAlert = true
                        }
                    )
                }
                
                Section(header: Text("Preferences")) {
                    Picker("Distance Unit", selection: $distanceUnit) {
                        Text("Meters").tag("meters")
                        Text("Feet").tag("feet")
                    }
                    
                    Toggle("Keep Screen On", isOn: $keepScreenOn)
                    Toggle("Save Last Known Location", isOn: $saveLastLocation)
                    Toggle("Dark Mode", isOn: $darkMode)
                        .onChange(of: darkMode) { newValue in
                            setAppAppearance(darkMode: newValue)
                        }
                }
                
                Section(header: Text("Data")) {
                    Button(action: { clearSavedDevices() }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("Clear Saved Devices")
                                .foregroundColor(.red)
                        }
                    }
                }
                
                Section(header: Text("About")) {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundColor(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://example.com/privacy-policy")!) {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Link(destination: URL(string: "https://example.com/terms")!) {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "arrow.up.forward.square")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Location Permission Required", isPresented: $showLocationPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { openSettings() }
            } message: {
                Text("Please enable location access in Settings to use this feature.")
            }
            .alert("Bluetooth Permission Required", isPresented: $showBluetoothPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { openSettings() }
            } message: {
                Text("Please enable Bluetooth in Settings to use this feature.")
            }
            .alert("Notification Permission Required", isPresented: $showNotificationPermissionAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Open Settings") { openSettings() }
            } message: {
                Text("Please enable notifications in Settings to receive alerts when devices are found.")
            }
            .onAppear {
                // Ensure the UI matches the current setting when view appears
                setAppAppearance(darkMode: darkMode)
            }
        }
    }
    
    private func permissionButton(title: String, systemImage: String, authorized: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: systemImage)
                    .foregroundColor(authorized ? .green : .red)
                
                Text(title)
                
                Spacer()
                
                Text(authorized ? "Authorized" : "Not Authorized")
                    .foregroundColor(authorized ? .green : .red)
            }
        }
    }
    
    private func clearSavedDevices() {
        UserDefaults.standard.removeObject(forKey: "savedDevices")
    }
    
    private func openSettings() {
        guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsUrl)
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
    SettingsView()
        .environmentObject(DeviceManager())
} 