import SwiftUI
import MapKit
import CoreLocation
import AudioToolbox

struct DeviceDetailView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @ObservedObject var device: Device
    @State private var isConnecting = false
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var showLocationDetail = false
    
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - Body View
    var body: some View {
        VStack(spacing: 24) {
            // Top navigation
            HStack {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 20))
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                Text(device.name)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    deviceManager.toggleSaveDevice(device)
                    feedbackImpact()
                }) {
                    Image(systemName: device.isSaved ? "heart.fill" : "heart")
                        .font(.system(size: 20))
                        .foregroundColor(device.isSaved ? .red : .gray)
                }
            }
            .padding(.horizontal)
            
            // Connection status indicator
            HStack {
                Image(systemName: device.isConnected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(device.isConnected ? .green : .gray)
                
                Text(device.isConnected ? "Connected" : "Disconnected")
                    .font(.subheadline)
                    .foregroundColor(device.isConnected ? .green : .gray)
                
                if let batteryLevel = device.batteryLevel {
                    Spacer()
                    
                    // Battery indicator
                    HStack(spacing: 4) {
                        Image(systemName: batteryIconName)
                            .foregroundColor(batteryLevelColor)
                        
                        Text("\(batteryLevel)%")
                            .font(.subheadline.bold())
                            .foregroundColor(batteryLevelColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(batteryLevelColor.opacity(0.1))
                    )
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            
            Spacer()
            
            // Device icon with battery ring
            ZStack {
                // Battery level ring
                if let batteryLevel = device.batteryLevel {
                    Circle()
                        .stroke(Color(UIColor.systemGray5), lineWidth: 6)
                        .frame(width: 160, height: 160)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(batteryLevel) / 100)
                        .stroke(
                            batteryLevelColor,
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 160, height: 160)
                        .rotationEffect(.degrees(-90))
                }
                
                // Inner circle with device icon
                Circle()
                    .fill(Color(UIColor.tertiarySystemBackground))
                    .frame(width: 140, height: 140)
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                
                Image(systemName: deviceTypeIcon)
                    .font(.system(size: 70))
                    .foregroundColor(.blue)
                
                // Battery level text
                if let batteryLevel = device.batteryLevel {
                    VStack {
                        Spacer()
                        Text("\(batteryLevel)%")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(batteryLevelColor)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(
                                Capsule()
                                    .fill(Color(UIColor.systemBackground))
                                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                            )
                    }
                    .frame(width: 140, height: 140)
                    .offset(y: 30)
                }
            }
            .padding(.bottom, 36)
            
            // Action buttons - modernized design
            HStack(spacing: 20) {
                // Play Sound
                actionButton(
                    title: "Sound",
                    icon: "speaker.wave.2.fill",
                    color: .blue,
                    isEnabled: device.isConnected
                ) {
                    playSound()
                }
                
                // Location
                actionButton(
                    title: "Location",
                    icon: "location.fill", 
                    color: .green,
                    isEnabled: true
                ) {
                    showLocationDetail = true
                }
                
                // Vibrate
                actionButton(
                    title: "Vibrate",
                    icon: "iphone.radiowaves.left.and.right",
                    color: .purple,
                    isEnabled: device.isConnected
                ) {
                    vibrate()
                }
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Connect button
            Button(action: {
                handleConnectionAction()
            }) {
                Text(connectionButtonText)
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(width: UIScreen.main.bounds.width * 0.7, height: 50)
                    .background(device.isConnected ? Color.green : Color.blue)
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 2)
            }
            .disabled(isConnecting)
            .opacity(isConnecting ? 0.7 : 1)
            .overlay(
                Group {
                    if isConnecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
            )
            
            Spacer()
        }
        .padding(.vertical, 20)
        .background(Color(UIColor.systemBackground))
        .sheet(isPresented: $showLocationDetail) {
            LocationDetailView(device: device)
        }
        .navigationBarHidden(true)
        .onAppear {
            updateDeviceInfo()
            
            // Attempt to connect if needed
            if !device.isConnected {
                deviceManager.connect(to: device)
            }
            
            // Setup a timer to periodically check connection and update info
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateDeviceInfo()
                
                // Read battery level periodically if connected
                if device.isConnected {
                    deviceManager.updateBatteryLevel(for: device)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
        .overlay(
            ToastView(message: toastMessage, isShowing: $showToast)
        )
    }
    
    // MARK: - Sub Views
    
    private func actionButton(title: String, icon: String, color: Color, isEnabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: {
            if isEnabled {
                action()
            } else {
                showConnectionNeededToast()
            }
        }) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isEnabled ? color : .gray)
                }
                
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isEnabled ? .primary : .gray)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .disabled(!isEnabled)
    }
    
    // MARK: - Helper Properties
    
    private var deviceTypeIcon: String {
        switch device.type {
        case .headphones: return "airpodspro"
        case .speaker: return "hifispeaker.fill"
        case .watch: return "applewatch"
        case .keyboard: return "keyboard.fill"
        case .mouse: return "mouse.fill"
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .computer: return "desktopcomputer"
        case .unknown: return "questionmark.circle.fill"
        }
    }
    
    private var batteryIconName: String {
        guard let level = device.batteryLevel else { return "battery.0" }
        
        if level <= 10 {
            return "battery.0"
        } else if level <= 25 {
            return "battery.25"
        } else if level <= 50 {
            return "battery.50" 
        } else if level <= 75 {
            return "battery.75"
        } else {
            return "battery.100"
        }
    }
    
    private var connectionButtonText: String {
        if isConnecting {
            return "Connecting..."
        } else if device.isConnected {
            return "Disconnect"
        } else {
            return "Connect"
        }
    }
    
    private var batteryLevelColor: Color {
        guard let level = device.batteryLevel else { return .gray }
        
        if level > 70 {
            return .green
        } else if level > 30 {
            return .orange
        } else {
            return .red
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateDeviceInfo() {
        // Get latest device data
        if let updatedDevice = deviceManager.devices.first(where: { $0.id == device.id }) {
            // Eğer bağlıysa, pil seviyesi güncellemesini dene
            if updatedDevice.isConnected && (updatedDevice.batteryLevel == nil) {
                print("Attempting to read battery level for \(updatedDevice.name)")
                deviceManager.readBatteryLevel(for: updatedDevice)
            }
        }
    }
    
    private func showConnectionNeededToast() {
        toastMessage = "Connect to the device first"
        showToast = true
    }

    private func playSound() {
        // Öncelikle cihaz tipini kontrol edelim
        if device.type == .watch {
            toastMessage = "Playing sound on Apple Watch..."
        } else {
            toastMessage = "Playing sound on \(device.name)..."
        }
        showToast = true
        
        // Ses çalmayı dene
        deviceManager.playSound(on: device)
    }

    private func vibrate() {
        // Öncelikle cihaz tipini kontrol edelim
        if device.type == .watch {
            toastMessage = "Vibrating Apple Watch..."
        } else {
            toastMessage = "Vibrating \(device.name)..."
        }
        showToast = true
        
        // Titreşim başlatmayı dene
        deviceManager.vibrateDevice(on: device)
    }

    private func feedbackSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func feedbackImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }
    
    private func handleConnectionAction() {
        if device.isConnected {
            deviceManager.disconnect(from: device)
            toastMessage = "Disconnected from device"
            showToast = true
        } else {
            isConnecting = true
            toastMessage = "Connecting to device..."
            showToast = true
            
            deviceManager.connect(to: device)
            
            // Check connection status after a delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                isConnecting = false
                
                // Get the updated device status
                if let updatedDevice = deviceManager.devices.first(where: { $0.id == device.id }) {
                    if updatedDevice.isConnected {
                        toastMessage = "Connected successfully!"
                        showToast = true
                        
                        deviceManager.discoverDeviceServices(for: updatedDevice)
                        deviceManager.readBatteryLevel(for: updatedDevice)
                    } else {
                        toastMessage = "Connection failed. Try again."
                        showToast = true
                    }
                }
            }
        }
    }
}

// MARK: - Location Detail Sheet
struct LocationDetailView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @ObservedObject var device: Device
    @Environment(\.dismiss) private var dismiss
    @State private var showToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if let location = device.lastLocation {
                    Map(coordinateRegion: .constant(MKCoordinateRegion(
                        center: location.coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )), annotationItems: [device]) { deviceItem in
                        MapAnnotation(coordinate: location.coordinate) {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.blue)
                        }
                    }
                    .edgesIgnoringSafeArea(.all)
                    
                    VStack(spacing: 16) {
                        if let lastSeen = device.lastSeen {
                            Text("Last seen \(formatTimeAgo(from: lastSeen))")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Button(action: {
                            updateLocation()
                        }) {
                            Label("Update Location", systemImage: "arrow.clockwise")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "location.slash")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                            .padding()
                        
                        Text("No Location Available")
                            .font(.headline)
                        
                        Text("Connect to the device to update its location")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: {
                            if device.isConnected {
                                updateLocation()
                            } else {
                                deviceManager.connect(to: device)
                                toastMessage = "Connecting to update location..."
                                showToast = true
                            }
                        }) {
                            Text(device.isConnected ? "Update Location" : "Connect & Update")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                        .padding(.top)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                }
            }
            .navigationTitle("Device Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
            }
            .overlay(
                ToastView(message: toastMessage, isShowing: $showToast)
            )
        }
    }
    
    private func updateLocation() {
        deviceManager.updateDeviceLocation(device)
        toastMessage = "Updating location..."
        showToast = true
    }
    
    private func formatTimeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            if isShowing {
                VStack {
                    Text(message)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .transition(.move(edge: .bottom))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                withAnimation {
                                    isShowing = false
                                }
                            }
                        }
                }
                .padding(.bottom, 80)
            }
        }
    }
}

