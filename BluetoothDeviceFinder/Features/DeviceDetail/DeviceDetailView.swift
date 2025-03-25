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
    
    // MARK: - Body View
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header with back button and favorite
                    headerView
                    
                    // Signal Strength Indicator
                    signalStrengthView
                        .padding(.horizontal, 20)
                    
                    // Action buttons
                    actionButtonsView
                    
                    // Map view (conditional)
                    if showLocationView {
                        locationMapView
                    }
                    
                    Spacer()
                    
                    // Found It Button
                    Button(action: {
                        deviceManager.deviceFound(device)
                        feedbackSuccess()
                        showToast = true
                        toastMessage = "Device marked as found!"
                    }) {
                        Text("Found It!")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                            .shadow(radius: 3)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
                .padding()
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            updateDeviceInfo()
            setupSignalStrength()
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
                    .font(.title2)
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            Text(device.name)
                .font(.title2)
                .fontWeight(.bold)
            
            Spacer()
            
            Button(action: {
                deviceManager.toggleSaveDevice(device)
                feedbackImpact()
            }) {
                Image(systemName: device.isSaved ? "heart.fill" : "heart")
                    .font(.title2)
                    .foregroundColor(device.isSaved ? .red : .gray)
            }
        }
    }
    
    private var signalStrengthView: some View {
        VStack(spacing: 16) {
            // Device image and signal strength
            ZStack {
                // Proximity info text
                Text(getProximityText())
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 180)
                
                // Signal strength circular track
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 20)
                    .frame(width: 180, height: 180)
                
                // Signal strength indicator
                Circle()
                    .trim(from: 0, to: signalStrength)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 20, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 1.0), value: signalStrength)
                
                // Device image
                deviceImage
                    .frame(width: 100, height: 100)
                    .padding()
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.1), radius: 5)
                
                // Signal strength percentage text
                Text("\(Int(signalStrength * 100))%")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .padding(.top, 180)
            }
            .frame(height: 230)
        }
        .padding(.vertical, 20)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            // Sound button
            ActionButton(
                title: "Sound",
                icon: "speaker.wave.3.fill",
                color: .blue
            ) {
                playSound()
            }
            
            // Vibrate button
            ActionButton(
                title: "Vibrate",
                icon: "waveform.path",
                color: .orange
            ) {
                vibrate()
            }
            
            // Location button
            ActionButton(
                title: "Location",
                icon: "location.fill",
                color: .green
            ) {
                withAnimation(.spring()) {
                    showLocationView.toggle()
                }
            }
        }
        .padding(.top, 24)
    }
    
    private var locationMapView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Map title with close button
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(device.name)")
                        .font(.headline)
                    
                    if let location = device.location {
                        Text("Last seen \(formatTimeAgo(from: location.timestamp))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        showLocationView = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16))
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
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
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 40, height: 40)
                                
                                Image(systemName: deviceTypeIcon)
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                            }
                            
                            // Triangle pointer
                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: 20, height: 10)
                                .rotationEffect(.degrees(45))
                                .offset(y: -5)
                        }
                    }
                }
                .frame(height: 300)
                .cornerRadius(16)
                .padding(.horizontal)
                
                // Directions button
                Button(action: {
                    // Open in Maps
                    if let location = device.location {
                        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
                        mapItem.name = device.name
                        mapItem.openInMaps()
                    }
                }) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("Directions")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
            } else {
                Text("No location data available for this device")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            }
        }
        .padding(.vertical)
        .background(Color(.systemGray6))
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.1), radius: 5)
    }
    
    private var deviceImage: some View {
        ZStack {
            // Use custom images based on device type
            Group {
                switch device.type {
                case .headphones:
                    Image("headphones")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .speaker:
                    Image("speaker")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .watch:
                    Image("watch")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .keyboard:
                    Image("keyboard")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .mouse:
                    Image("mouse")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .phone:
                    Image("phone")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .tablet:
                    Image("tablet")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .laptop:
                    Image("laptop")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .computer:
                    Image("computer")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                case .unknown:
                    // Fallback to system icons if no custom image
                    Image(systemName: deviceTypeIcon)
                        .font(.system(size: 40))
                        .foregroundColor(.blue)
                }
            }
            .padding(5)
        }
    }
    
    // MARK: - Helper Properties
    
    private var deviceTypeIcon: String {
        switch device.type {
        case .headphones:
            return "headphones"
        case .speaker:
            return "hifispeaker"
        case .watch:
            return "applewatch"
        case .keyboard:
            return "keyboard"
        case .mouse:
            return "mouse"
        case .phone:
            return "iphone"
        case .tablet:
            return "ipad"
        case .laptop:
            return "laptopcomputer"
        case .computer:
            return "desktopcomputer"
        case .unknown:
            return "questionmark.circle"
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateDeviceInfo() {
        // Attempt to get updated device info
        if let updatedDevice = deviceManager.devices.first(where: { $0.id == device.id }) {
            self.device = updatedDevice
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
            signalStrength = 0.5
        }
    }
    
    private func getProximityText() -> String {
        guard let rssi = device.rssi else { return "Unknown proximity" }
        
        // Using a simple path loss model to estimate distance
        let txPower = -59 // Calibrated at 1 meter
        let n = 2.5 // Path loss exponent (environment dependent)
        
        // Calculate approximate distance in meters
        let distance = pow(10, (Double(txPower - rssi) / (10 * n)))
        
        return "You are very close to this device. Move around for the signal strength to increase."
    }
    
    private func formatTimeAgo(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // Play sound ve vibrate fonksiyonları View içine taşınıyor
    private func playSound() {
        // Create a system sound
        AudioServicesPlaySystemSound(1005) // This is a common system sound
        
        // Show toast
        toastMessage = "Playing sound on device..."
        showToast = true
    }

    private func vibrate() {
        // Create a vibration pattern
        for _ in 1...3 {
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            Thread.sleep(forTimeInterval: 0.5)
        }
        
        // Show toast
        toastMessage = "Sending vibration to device..."
        showToast = true
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

#Preview {
    DeviceDetailView(device: Device(name: "Preview Device", rssi: -65, batteryLevel: 75))
        .environmentObject(DeviceManager())
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

// Add ActionButton struct
struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(color)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.callout)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
} 
