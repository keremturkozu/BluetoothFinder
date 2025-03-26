import SwiftUI
import MapKit
import CoreLocation
import AudioToolbox

struct DeviceDetailView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @State var device: Device
    @State private var isConnecting = false
    @State private var showLocationAlert = false
    @State private var showLocationView = false
    @State private var signalStrength: Double = 0.0
    @State private var mapRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @Environment(\.dismiss) private var dismiss
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var lastBatteryUpdateTime = Date(timeIntervalSince1970: 0)
    
    // MARK: - Body View
    var body: some View {
        VStack(spacing: 0) {
            // Header with back button and favorite
            headerView
                .padding(.horizontal)
                .padding(.top)
            
            // Main content
            VStack(spacing: 20) {
                // Main signal strength and device image
                ZStack {
                    // Signal strength circular track
                    Circle()
                        .stroke(Color.blue.opacity(0.2), lineWidth: 12)
                        .frame(width: 240, height: 240)
                    
                    // Signal strength indicator
                    Circle()
                        .trim(from: 0, to: signalStrength)
                        .stroke(
                            Color.blue,
                            style: StrokeStyle(lineWidth: 12, lineCap: .round)
                        )
                        .frame(width: 240, height: 240)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 1.0), value: signalStrength)
                    
                    // Device image
                    deviceImage
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.1), radius: 2)
                }
                
                // Signal strength percentage text
                VStack(spacing: 4) {
                    Text("\(Int(signalStrength * 100))%")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    // Proximity text moved here
                    Text(getProximityText())
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, -10)
                
                // Quick Action Buttons
                HStack(spacing: 30) {
                    // Sound button
                    quickActionButton(icon: "speaker.wave.2.fill", color: .blue, text: "Sound") {
                        if device.isConnected {
                            playSound()
                        } else {
                            showConnectionNeededToast()
                        }
                    }
                    
                    // Vibrate button
                    quickActionButton(icon: "iphone.radiowaves.left.and.right", color: .orange, text: "Vibrate") {
                        if device.isConnected {
                            vibrate()
                        } else {
                            showConnectionNeededToast()
                        }
                    }
                    
                    // Location button
                    quickActionButton(icon: "location.fill", color: .green, text: "Location") {
                        withAnimation(.spring()) {
                            showLocationView.toggle()
                        }
                    }
                }
                .padding(.top, 10)

                // Connect button
                connectButton
                    .padding(.top, 5)
                
                // Map view (conditional)
                if showLocationView {
                    locationMapView
                }
                
                Spacer()
                
                // Mark as found Button (renamed from "Found It")
                Button(action: {
                    deviceManager.deviceFound(device)
                    feedbackSuccess()
                    showToast = true
                    toastMessage = "Device marked as found!"
                }) {
                    Text("Mark as Recovered")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 16)
            }
            .padding()
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            updateDeviceInfo()
            setupSignalStrength()
            
            // Attempt to connect if needed
            if !device.isConnected {
                print("Device not connected, attempting to connect...")
                deviceManager.connect(to: device)
            }
            
            // Setup a timer to periodically check connection and update signal
            let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                updateDeviceInfo()
                setupSignalStrength()
                
                // Read battery level periodically if connected
                if device.isConnected {
                    deviceManager.updateBatteryLevel(for: device)
                }
            }
            
            // Store the timer so we can invalidate it later
            // This is important to prevent memory leaks
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                RunLoop.current.add(timer, forMode: .common)
            }
        }
        .overlay(
            ToastView(message: toastMessage, isShowing: $showToast)
        )
    }
    
    // MARK: - UI Components
    
    private var headerView: some View {
        HStack {
            Button(action: {
                dismiss()
            }) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text(device.name)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(1)
                
                if device.type != .unknown {
                    Text(deviceTypeName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button(action: {
                deviceManager.toggleSaveDevice(device)
                feedbackImpact()
            }) {
                Image(systemName: device.isSaved ? "heart.fill" : "heart")
                    .font(.title3)
                    .foregroundColor(device.isSaved ? .red : .gray)
            }
        }
    }
    
    private var connectButton: some View {
        Button(action: {
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
                        self.device = updatedDevice
                        
                        if updatedDevice.isConnected {
                            toastMessage = "Connected successfully!"
                            showToast = true
                            
                            // Bağlantı başarılı olduğunda hizmetleri keşfet ve pil seviyesini oku
                            deviceManager.discoverDeviceServices(for: updatedDevice)
                            deviceManager.readBatteryLevel(for: updatedDevice)
                        } else {
                            toastMessage = "Connection failed. Try again."
                            showToast = true
                        }
                    }
                }
            }
        }) {
            HStack {
                Image(systemName: device.isConnected ? "link.badge.minus" : "link.badge.plus")
                    .font(.system(size: 16))
                
                Text(connectionButtonText)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(device.isConnected ? Color.green : Color.blue)
            .cornerRadius(20)
            .shadow(color: (device.isConnected ? Color.green : Color.blue).opacity(0.3), radius: 4, x: 0, y: 2)
            .opacity(isConnecting ? 0.6 : 1.0)
        }
        .disabled(isConnecting)
        .overlay(
            Group {
                if isConnecting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
        )
    }
    
    private var deviceImage: some View {
        ZStack {
            // Device type background
            Circle()
                .fill(Color.white)
                .frame(width: 130, height: 130)
                .shadow(color: Color.black.opacity(0.1), radius: 3)
            
            // Battery overlay
            if let batteryLevel = device.batteryLevel {
                VStack {
                    HStack {
                        Spacer()
                        
                        // Battery indicator
                        Text("\(batteryLevel)%")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(batteryLevelColor)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                            .padding(8)
                    }
                    
                    Spacer()
                }
                .frame(width: 130, height: 130)
            }
            
            // Device icon
            Image(systemName: deviceTypeIcon)
                .font(.system(size: 60))
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
        }
    }
    
    private var locationMapView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Last Known Location")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showLocationView = false
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.gray)
                }
            }
            .padding(.horizontal)
            
            // Map
            if let location = device.location {
                Map(coordinateRegion: .constant(MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )), annotationItems: [device]) { device in
                    MapAnnotation(coordinate: location.coordinate) {
                        VStack {
                            Image(systemName: "location.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.blue)
                        }
                    }
                }
                .frame(height: 200)
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Last seen time
                if let timestamp = device.location?.timestamp {
                    Text("Last seen \(formatTimeAgo(from: timestamp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                }
            } else {
                Text("No location data available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding(.vertical, 8)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
    
    // MARK: - Helper Components
    
    private func quickActionButton(icon: String, color: Color, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .frame(width: 52, height: 52)
                    .foregroundColor(.white)
                    .background(color)
                    .clipShape(Circle())
                    .shadow(color: color.opacity(0.4), radius: 4, x: 0, y: 2)
                
                Text(text)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var deviceTypeIcon: String {
        switch device.type {
        case .headphones:
            return "airpodspro"
        case .speaker:
            return "hifispeaker.fill"
        case .watch:
            return "applewatch"
        case .keyboard:
            return "keyboard.fill"
        case .mouse:
            return "mouse.fill"
        case .phone:
            return "iphone"
        case .tablet:
            return "ipad"
        case .laptop:
            return "laptopcomputer"
        case .computer:
            return "desktopcomputer"
        case .unknown:
            return "questionmark.circle.fill"
        }
    }
    
    private var deviceTypeName: String {
        switch device.type {
        case .headphones:
            return "Earphones"
        case .speaker:
            return "Speaker"
        case .watch:
            return "Watch"
        case .keyboard:
            return "Keyboard"
        case .mouse:
            return "Mouse"
        case .phone:
            return "Phone"
        case .tablet:
            return "Tablet"
        case .laptop:
            return "Laptop"
        case .computer:
            return "Computer"
        case .unknown:
            return "Unknown Device"
        }
    }
    
    private var connectionButtonText: String {
        if isConnecting {
            return "Connecting..."
        } else if device.isConnected {
            return "Connected"
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
        // Attempt to get updated device info
        if let updatedDevice = deviceManager.devices.first(where: { $0.id == device.id }) {
            self.device = updatedDevice
            
            // Debug information
            print("Signal strength (RSSI): \(device.rssi ?? 0)")
            print("Connected: \(device.isConnected)")
            print("Battery level: \(device.batteryLevel ?? 0)%")
            
            // Update title with connection status
            if device.isConnected {
                // Periodically update the battery level if the device is connected
                if Date().timeIntervalSince(lastBatteryUpdateTime) > 5.0 {
                    deviceManager.readBatteryLevel(for: updatedDevice)
                    lastBatteryUpdateTime = Date()
                }
            }
        }
        
        // Set map region if location exists
        if let location = device.location {
            mapRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        }
    }
    
    private func setupSignalStrength() {
        // Calculate signal strength as a percentage (0-1)
        if let rssi = device.rssi {
            // Convert RSSI to percentage (approx)
            // -30 is excellent (100%), -90 is poor (0%)
            let rssiRange: Double = 60 // from -30 to -90
            let adjustedRSSI = Double(min(max(-90, rssi), -30))
            let percentage = (adjustedRSSI + 90) / rssiRange
            
            // Animate to new value
            withAnimation {
                signalStrength = percentage
            }
        } else {
            // Default value if no RSSI
            signalStrength = 0.0
        }
    }
    
    private func getProximityText() -> String {
        guard let rssi = device.rssi else { return "Move around to improve signal detection" }
        
        let distance = deviceManager.calculateDistance(rssi: rssi)
        
        if distance < 1 {
            return "Device is within reach, you're very close"
        } else if distance < 3 {
            return "Getting closer, follow the signal strength"
        } else if distance < 10 {
            return "Device is nearby, keep searching"
        } else {
            return "Move around to get a stronger signal"
        }
    }
    
    private func formatTimeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func showConnectionNeededToast() {
        toastMessage = "Connect to device first for this action"
        showToast = true
    }

    private func playSound() {
        let success = deviceManager.playSound(on: device)
        
        if success {
            // Sistem sesi olarak simule et
            AudioServicesPlaySystemSound(1005)
            
            toastMessage = "Playing sound on device..."
            showToast = true
        } else {
            toastMessage = "Failed to play sound on device"
            showToast = true
        }
    }

    private func vibrate() {
        let success = deviceManager.vibrateDevice(device)
        
        if success {
            // Sistem titreşimi olarak simüle et
            for _ in 1...3 {
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
                Thread.sleep(forTimeInterval: 0.3)
            }
            
            toastMessage = "Sending vibration to device..."
            showToast = true
        } else {
            toastMessage = "Failed to vibrate device. Make sure it's connected."
            showToast = true
        }
    }

    private func feedbackSuccess() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func feedbackImpact() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
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

#Preview {
    DeviceDetailView(device: Device(name: "Steven Wood's Earphones", rssi: -65, batteryLevel: 75, type: .headphones))
        .environmentObject(DeviceManager())
} 
