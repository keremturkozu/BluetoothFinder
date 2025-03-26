import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @StateObject private var viewModel = DeviceListViewModel()
    
    // Timer ekleyerek sürekli mesafe güncellemesi sağlayalım
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var updateCounter: Int = 0
    @State private var showSortOptions: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.devices.isEmpty {
                    emptyStateView
                } else {
                    deviceListView
                }
                
                VStack {
                    if deviceManager.errorMessage != nil {
                        // Error message banner
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.yellow)
                            
                            Text(deviceManager.errorMessage ?? "")
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                // Yetki hatası için ayarlara yönlendir
                                if deviceManager.errorMessage?.contains("Bluetooth") ?? false {
                                    if let url = URL(string: UIApplication.openSettingsURLString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }) {
                                Text("Settings")
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                        .padding()
                        .background(Color.yellow.opacity(0.2))
                        .cornerRadius(8)
                        .padding(.horizontal)
                        .padding(.top)
                    }
                    
                    Spacer()
                    
                    scanButton
                        .padding(.bottom)
                }
            }
            .navigationTitle("Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    sortButton
                }
            }
        }
        .sheet(isPresented: $showSortOptions) {
            sortOptionsView
        }
        .onAppear {
            viewModel.injectDeviceManager(deviceManager)
            // Uygulamayı açtığımızda Bluetooth durumunu hemen kontrol edelim
            deviceManager.checkAndUpdateBluetoothState()
            // Debug amaçlı
            print("DeviceListView appeared - Bluetooth enabled: \(deviceManager.isBluetoothEnabled)")
        }
        .onReceive(timer) { _ in
            // Timer ile her 1 saniyede bir görünümü güncelleyerek mesafelerin sürekli yenilenmesini sağlayalım
            updateCounter += 1
        }
    }
    
    // MARK: - Helper Views
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            // Bluetooth scanning animation
            ZStack {
                // Outer circle (pulse effect when scanning)
                Circle()
                    .stroke(Color.blue.opacity(0.3), lineWidth: viewModel.isScanning ? 8 : 0)
                    .frame(width: 180, height: 180)
                    .scaleEffect(viewModel.isScanning ? 1.2 : 1.0)
                    .opacity(viewModel.isScanning ? 0.6 : 0)
                    .animation(viewModel.isScanning ? 
                        Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true) : .default, 
                        value: viewModel.isScanning)
                
                // Middle circle
                Circle()
                    .stroke(Color.blue.opacity(0.5), lineWidth: 6)
                    .frame(width: 120, height: 120)
                    .scaleEffect(viewModel.isScanning ? 1.1 : 1.0)
                    .opacity(viewModel.isScanning ? 0.8 : 0.5)
                    .animation(viewModel.isScanning ? 
                        Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true) : .default, 
                        value: viewModel.isScanning)
                
                // Inner circle with bluetooth icon
                Circle()
                    .fill(Color.blue)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Image(systemName: deviceManager.isBluetoothEnabled ? "bluetooth" : "bluetooth.slash")
                            .font(.system(size: 30, weight: .bold))
                            .foregroundColor(.white)
                    )
                    .shadow(color: Color.blue.opacity(0.5), radius: 10, x: 0, y: 5)
            }
            .padding(.bottom, 20)
            
            if !deviceManager.isBluetoothEnabled {
                Text("Bluetooth is Disabled")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Please enable Bluetooth in your device settings")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
                
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(25)
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            } else {
                Text(viewModel.isScanning ? "Scanning for Devices..." : "No Devices Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(viewModel.isScanning ? 
                    "Looking for nearby Bluetooth devices" : 
                    "Start scanning to find nearby devices")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 10)
            }
        }
    }
    
    private var deviceListView: some View {
        List {
            if viewModel.isScanning {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                    
                    Text("Scanning for devices...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 10)
                    
                    Spacer()
                }
                .listRowBackground(Color(.systemGray6))
                .listRowSeparator(.hidden)
                .padding(.vertical, 8)
            }
            
            ForEach(viewModel.devices) { device in
                DeviceRowView(device: device)
                    .onTapGesture {
                        viewModel.selectDevice(device)
                    }
                    .contextMenu {
                        Button(action: { viewModel.toggleConnection(for: device) }) {
                            Label(
                                device.isConnected ? "Disconnect" : "Connect",
                                systemImage: device.isConnected ? "link.slash" : "link"
                            )
                        }
                        
                        Button(action: { viewModel.toggleSaveDevice(device) }) {
                            Label(
                                device.isSaved ? "Remove Favorite" : "Add to Favorites",
                                systemImage: device.isSaved ? "heart.slash" : "heart"
                            )
                        }
                        
                        Button(action: { viewModel.forgetDevice(device) }) {
                            Label("Forget Device", systemImage: "trash")
                        }
                    }
            }
            .onDelete(perform: viewModel.deleteDevices)
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            viewModel.refreshDevices()
        }
        .sheet(item: $viewModel.selectedDevice) { device in
            DeviceDetailView(device: device)
        }
    }
    
    private var scanButton: some View {
        Button(action: {
            viewModel.isScanning ? viewModel.stopScanning() : viewModel.startScanning()
        }) {
            HStack {
                // Rotate animation for the icon when scanning
                Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                    .rotationEffect(viewModel.isScanning ? .degrees(0) : .degrees(0))
                    .animation(
                        viewModel.isScanning ?
                            Animation.linear(duration: 2).repeatForever(autoreverses: false) : .default,
                        value: viewModel.isScanning
                    )
                
                Text(viewModel.isScanning ? "Stop Scanning" : "Scan for Devices")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 25)
                    .fill(viewModel.isScanning ? Color.red : Color.blue)
                    .shadow(color: (viewModel.isScanning ? Color.red : Color.blue).opacity(0.4), radius: 8, x: 0, y: 4)
            )
            .padding(.horizontal, 30)
        }
    }
    
    private var sortButton: some View {
        Menu {
            Button(action: viewModel.sortByName) {
                Label("Sort by Name", systemImage: "textformat.size")
            }
            
            Button(action: viewModel.sortBySignalStrength) {
                Label("Sort by Signal", systemImage: "antenna.radiowaves.left.and.right")
            }
            
            Button(action: viewModel.sortByLastSeen) {
                Label("Sort by Last Seen", systemImage: "clock")
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }
    
    private var sortOptionsView: some View {
        // Implementation of sortOptionsView
        Text("Sort Options View")
    }
    
    // MARK: - Helper Functions
    private func startScanning() {
        viewModel.startScanning()
    }
}

struct DeviceRowView: View {
    let device: Device
    @EnvironmentObject private var deviceManager: DeviceManager
    
    // Mesafeyi doğru hesaplamak için her yenilemede değişen state
    @State private var distanceValue: Double = 0
    
    var body: some View {
        HStack(spacing: 16) {
            // Device image with background
            ZStack {
                // Background circle with gradient based on signal strength
                Circle()
                    .fill(signalGradient)
                    .frame(width: 56, height: 56)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                
                // Device icon
                Image(systemName: deviceTypeIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            .frame(width: 56, height: 56)
            
            // Device info
            VStack(alignment: .leading, spacing: 4) {
                // Device name
                Text(device.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // Signal and battery info
                HStack(spacing: 12) {
                    // Distance indicator
                    HStack(spacing: 4) {
                        Image(systemName: distanceIcon)
                            .font(.system(size: 12))
                            .foregroundColor(signalColor)
                        
                        Text(formatDistance(for: device))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Battery if available
                    if let battery = device.batteryLevel {
                        HStack(spacing: 4) {
                            Image(systemName: batteryIcon)
                                .font(.system(size: 12))
                                .foregroundColor(batteryColor)
                            
                            Text("\(battery)%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Connected status
                    if device.isConnected {
                        Text("Connected")
                            .font(.caption)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
            }
            
            Spacer()
            
            // Signal strength indicator
            signalStrengthIndicator
                .padding(.trailing, 8)
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onAppear {
            // İlk gösterimde mesafeyi hesapla
            updateDistance()
        }
        .onChange(of: device.rssi) { oldValue, newValue in
            // RSSI değiştiğinde mesafeyi güncelle
            updateDistance()
        }
    }
    
    // MARK: - UI Components
    
    private var signalStrengthIndicator: some View {
        VStack(spacing: 1) {
            ForEach(0..<4) { i in
                RoundedRectangle(cornerRadius: 1)
                    .frame(width: 3 + CGFloat(i), height: 6 + CGFloat(i * 2))
                    .foregroundColor(signalStrengthColor(for: i))
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var distanceIcon: String {
        guard let rssi = device.rssi else { return "location.slash" }
        
        if rssi > -50 {
            return "location.fill"
        } else if rssi > -65 {
            return "location"
        } else if rssi > -80 {
            return "location"
        } else {
            return "location.slash"
        }
    }
    
    private var signalGradient: LinearGradient {
        guard let rssi = device.rssi else {
            return LinearGradient(
                gradient: Gradient(colors: [Color.gray.opacity(0.7), Color.gray.opacity(0.9)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        if rssi > -50 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.green.opacity(0.7), Color.green]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if rssi > -65 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.7), Color.blue]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if rssi > -80 {
            return LinearGradient(
                gradient: Gradient(colors: [Color.orange.opacity(0.7), Color.orange]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            return LinearGradient(
                gradient: Gradient(colors: [Color.red.opacity(0.7), Color.red]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func signalStrengthColor(for bar: Int) -> Color {
        guard let rssi = device.rssi else { return Color.gray.opacity(0.3) }
        
        let signalStrength = calculateSignalStrength(rssi: rssi)
        
        // Determine if this bar should be colored based on signal strength
        let threshold = Double(bar) / 3.0
        
        if signalStrength >= threshold {
            return signalColor
        } else {
            return Color.gray.opacity(0.3)
        }
    }
    
    private func calculateSignalStrength(rssi: Int) -> Double {
        // Convert RSSI to a percentage (0-1)
        // -30 is excellent (100%), -90 is poor (0%)
        let rssiRange: Double = 60.0
        let adjustedRSSI = Double(min(max(-90, rssi), -30))
        return (adjustedRSSI + 90) / rssiRange
    }
    
    // MARK: - Helper Properties & Methods
    
    private var batteryColor: Color {
        guard let battery = device.batteryLevel else { return .gray }
        
        if battery > 75 {
            return .green
        } else if battery > 30 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private var signalColor: Color {
        guard let rssi = device.rssi else { return .gray }
        
        if rssi > -50 {
            return .green
        } else if rssi > -65 {
            return .blue
        } else if rssi > -80 {
            return .orange
        } else {
            return .red
        }
    }
    
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
    
    private var batteryIcon: String {
        guard let battery = device.batteryLevel else { return "battery.0" }
        
        if battery > 75 {
            return "battery.100"
        } else if battery > 50 {
            return "battery.75"
        } else if battery > 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
    
    // Distance calculation and formatting based on RSSI
    private func formatDistance(for device: Device) -> String {
        guard let rssi = device.rssi else { return "Unknown" }
        
        // DeviceManager'ın hesaplama fonksiyonunu kullan
        let distance = deviceManager.calculateDistance(rssi: rssi)
        
        if distance < 0 {
            return "Unknown"
        } else if distance < 1 {
            return String(format: "%.1f m away", distance)
        } else if distance < 10 {
            return String(format: "%.1f m away", distance)
        } else {
            return "\(Int(distance)) m away"
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateDistance() {
        guard let rssi = device.rssi else { return }
        // DeviceManager'ın hesaplama fonksiyonunu kullan
        distanceValue = deviceManager.calculateDistance(rssi: rssi)
    }
}

#Preview {
    DeviceListView()
        .environmentObject(DeviceManager())
} 
