import SwiftUI
import CoreLocation

struct DashboardView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @State private var isScanning = false
    @State private var showDeviceDetail = false
    @State private var selectedDevice: Device?
    @State private var totalDevicesFound = 0
    @State private var animatedBarHeight: [CGFloat] = [30, 45, 60, 40, 50, 35, 55, 65, 48, 52]
    
    // Colors for device status summary
    private let gradientColors = [Color.blue, Color.purple]
    private let cardBackgroundColor = Color(UIColor.secondarySystemGroupedBackground)
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 12) {
                    // Header Card - Main card
                    headerCard
                        .padding(.horizontal)
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Signal Activity - Make it more useful
                    signalActivitySection
                    
                    // Nearby devices
                    nearbyDevicesSection
                }
                .padding(.top, 8)
                .padding(.bottom)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDeviceDetail) {
                if let selectedDevice = selectedDevice {
                    DeviceDetailView(device: selectedDevice)
                }
            }
            .onAppear {
                // Update Bluetooth status
                isScanning = deviceManager.isScanning
                animateGraph()
            }
        }
    }
    
    // MARK: - UI Sections
    
    private var headerCard: some View {
        ZStack(alignment: .bottom) {
            // Background gradient and shape
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(height: 170)
                .shadow(color: Color.primary.opacity(0.1), radius: 10, x: 0, y: 5)
            
            // Content
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Bluetooth Finder")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Track your devices")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    // Bluetooth status indicator
                    Circle()
                        .fill(deviceManager.isBluetoothEnabled ? Color.green : Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                .padding(.top, 20)
                
                Spacer()
                
                // Device statistics
                HStack {
                    Spacer()
                    
                    statBox(
                        value: deviceManager.devices.count,
                        label: "Found"
                    )
                    
                    Spacer()
                    
                    statBox(
                        value: deviceManager.devices.filter { $0.isSaved }.count,
                        label: "Saved"
                    )
                    
                    Spacer()
                    
                    statBox(
                        value: deviceManager.devices.filter { $0.isConnected }.count,
                        label: "Connected"
                    )
                    
                    Spacer()
                }
                .padding(.bottom, 16)
            }
            .padding(.horizontal, 20)
            .frame(maxWidth: .infinity)
        }
    }
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)
                .padding(.horizontal)
            
            HStack(spacing: 12) {
                // Scan button
                quickActionCard(
                    title: isScanning ? "Stop" : "Scan",
                    icon: isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right",
                    color: isScanning ? .red : .blue
                ) {
                    if isScanning {
                        deviceManager.stopScanning()
                    } else {
                        deviceManager.startScanning()
                    }
                    isScanning = deviceManager.isScanning
                }
                
                // Map button
                quickActionCard(
                    title: "Map",
                    icon: "map.fill",
                    color: .green
                ) {
                    selectTab(.map)
                }
                
                // Radar button
                quickActionCard(
                    title: "Radar",
                    icon: "scope",
                    color: .orange
                ) {
                    selectTab(.radar)
                }
            }
            .padding(.horizontal)
        }
    }
    
    private var signalActivitySection: some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Text("Signal Strength")
                    .font(.headline)
                
                Spacer()
                
                Text("Real-time monitoring")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // Signal strength graph with meaning
            VStack(spacing: 10) {
                // Graph
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(0..<animatedBarHeight.count, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: [.green, .blue]),
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(width: 7, height: animatedBarHeight[index])
                            .animation(.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0).delay(Double(index) * 0.05), value: animatedBarHeight[index])
                    }
                }
                .frame(height: 70)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
                
                // Signal ranges explanation
                HStack(spacing: 16) {
                    signalLegendItem(color: .green, text: "Excellent")
                    signalLegendItem(color: .blue, text: "Good")
                    signalLegendItem(color: .orange, text: "Fair")
                    signalLegendItem(color: .red, text: "Poor")
                }
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 8)
            }
            .padding(.vertical, 8)
            .background(cardBackgroundColor)
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    private var nearbyDevicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Nearby Devices")
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    selectTab(.devices)
                }) {
                    Text("View All")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal)
            
            // Nearby devices list (max 3)
            VStack(spacing: 0) {
                if deviceManager.devices.isEmpty {
                    nearbyDeviceEmptyView
                } else {
                    ForEach(nearbyDevices) { device in
                        NearbyDeviceRow(device: device)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedDevice = device
                                showDeviceDetail = true
                            }
                        
                        if device.id != nearbyDevices.last?.id {
                            Divider()
                                .padding(.leading, 76)
                        }
                    }
                }
            }
            .background(cardBackgroundColor)
            .cornerRadius(16)
            .padding(.horizontal)
        }
    }
    
    // MARK: - Helper Views
    
    private var nearbyDevices: [Device] {
        return deviceManager.devices
            .sorted { ($0.rssi ?? -100) > ($1.rssi ?? -100) }
            .prefix(3)
            .map { $0 }
    }
    
    private var nearbyDeviceEmptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 30))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, 20)
            
            Text("No devices found nearby")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Button(action: {
                deviceManager.startScanning()
                isScanning = true
            }) {
                Text("Start Scanning")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .cornerRadius(20)
            }
            .padding(.vertical, 10)
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
    }
    
    private func quickActionCard(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 20))
                            .foregroundColor(color)
                    )
                
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: Color.primary.opacity(0.1), radius: 3, x: 0, y: 2)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
            )
        }
    }
    
    private func statBox(value: Int, label: String) -> some View {
        VStack(spacing: 5) {
            Text("\(value)")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: 70)
    }
    
    private func signalLegendItem(color: Color, text: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(text)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private func animateGraph() {
        // Animate with device RSSI values or random if no data
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            var newHeights: [CGFloat] = []
            
            // If we have devices, use their signal strength to create a meaningful graph
            if !deviceManager.devices.isEmpty {
                // Get the devices' RSSI values
                let rssiValues = deviceManager.devices.compactMap { $0.rssi }
                
                // If we have less than 10 devices, fill the rest with random values
                if rssiValues.count < 10 {
                    let deviceValues = rssiValues.map { rssiToHeight($0) }
                    newHeights.append(contentsOf: deviceValues)
                    
                    // Add random values for the remaining bars
                    for _ in 0..<(10 - rssiValues.count) {
                        newHeights.append(CGFloat.random(in: 25...65))
                    }
                } else {
                    // If we have 10 or more devices, use the first 10
                    newHeights = rssiValues.prefix(10).map { rssiToHeight($0) }
                }
            } else {
                // If no devices, use random values
                for _ in 0..<10 {
                    newHeights.append(CGFloat.random(in: 25...65))
                }
            }
            
            // Apply animation
            withAnimation {
                animatedBarHeight = newHeights
            }
        }
    }
    
    // Convert RSSI value to bar height
    private func rssiToHeight(_ rssi: Int) -> CGFloat {
        // RSSI typically ranges from -30 (very strong) to -90 (very weak)
        // Convert to a height between 25 and 65
        let normalized = min(max(-90, rssi), -30) + 90 // Now 0 to 60
        return CGFloat(normalized) + 25 // Now 25 to 85
    }
    
    // MARK: - Helper Methods
    
    private func selectTab(_ tab: Tab) {
        // NotificationCenter ile tab geçişi yapma
        let userInfo = ["selectedTab": tab.rawValue]
        NotificationCenter.default.post(name: NSNotification.Name("SelectTab"), object: nil, userInfo: userInfo)
    }
}

// MARK: - Nearby Device Row View
struct NearbyDeviceRow: View {
    let device: Device
    @EnvironmentObject private var deviceManager: DeviceManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Device icon
            ZStack {
                Circle()
                    .fill(deviceTypeColor)
                    .frame(width: 48, height: 48)
                
                Image(systemName: deviceTypeIcon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    // Distance info
                    if let rssi = device.rssi {
                        HStack(spacing: 4) {
                            Image(systemName: "location")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            
                            let distance = deviceManager.calculateDistance(rssi: rssi)
                            if distance < 1 {
                                Text(String(format: "%.1f m", distance))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text(String(format: "%.0f m", distance))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Battery level (if available)
                    if let battery = device.batteryLevel {
                        HStack(spacing: 4) {
                            Image(systemName: batteryIcon(for: battery))
                                .font(.caption2)
                                .foregroundColor(batteryColor(for: battery))
                            
                            Text("\(battery)%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            // Signal strength indicator
            if let rssi = device.rssi {
                HStack(spacing: 2) {
                    ForEach(0..<signalBars(for: rssi), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .frame(width: 3, height: 12)
                            .foregroundColor(signalColor(for: rssi))
                    }
                    ForEach(0..<(4-signalBars(for: rssi)), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 1)
                            .frame(width: 3, height: 12)
                            .foregroundColor(.gray.opacity(0.3))
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .padding()
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
    
    private var deviceTypeColor: Color {
        switch device.type {
        case .headphones:
            return .blue
        case .speaker:
            return .purple
        case .watch:
            return .green
        case .keyboard, .mouse:
            return .orange
        case .phone, .tablet:
            return .pink
        case .laptop, .computer:
            return .indigo
        case .unknown:
            return .gray
        }
    }
    
    private func batteryIcon(for level: Int) -> String {
        if level > 75 {
            return "battery.100"
        } else if level > 50 {
            return "battery.75"
        } else if level > 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
    
    private func batteryColor(for level: Int) -> Color {
        if level > 75 {
            return .green
        } else if level > 30 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func signalBars(for rssi: Int) -> Int {
        if rssi > -50 {
            return 4
        } else if rssi > -65 {
            return 3
        } else if rssi > -80 {
            return 2
        } else {
            return 1
        }
    }
    
    private func signalColor(for rssi: Int) -> Color {
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
}

// Preview
struct DashboardView_Previews: PreviewProvider {
    static var previews: some View {
        DashboardView()
            .environmentObject(DeviceManager())
    }
} 