import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    @State private var showingSettingsSheet = false
    @State private var isShowingBluetoothAlert = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background color
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Main content
                VStack(spacing: 8) {
                    // Modernize scan header - more compact design
                    scanHeader
                    
                    // Main content list or empty view
                    if viewModel.filteredDevices.isEmpty {
                        emptyStateView
                            .padding(.top, 10)
                    } else {
                        deviceListView
                    }
                }
                .navigationTitle("Device Finder")
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Menu {
                            Toggle(isOn: $viewModel.hideUnnamedDevices) {
                                Label("Hide unnamed devices", systemImage: "tag")
                            }
                            
                            Button(action: {
                                showingSettingsSheet = true
                            }) {
                                Label("Settings", systemImage: "gear")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
                .sheet(isPresented: $showingSettingsSheet) {
                    SettingsView()
                }
                .alert(isPresented: $isShowingBluetoothAlert) {
                    Alert(
                        title: Text("Bluetooth is Disabled"),
                        message: Text("Please enable Bluetooth in Settings to scan for devices."),
                        dismissButton: .default(Text("OK"))
                    )
                }
            }
        }
        .onAppear {
            viewModel.checkBluetoothStatus()
        }
        // Show alert if Bluetooth is not enabled
        .onChange(of: viewModel.isBluetoothEnabled) { newValue in
            if !newValue && viewModel.isScanning {
                isShowingBluetoothAlert = true
            }
        }
    }
    
    // MARK: - UI Components
    
    private var scanHeader: some View {
        HStack(spacing: 16) {
            // Status indicator and bluetooth status
            HStack(spacing: 6) {
                Circle()
                    .frame(width: 8, height: 8)
                    .foregroundColor(viewModel.isBluetoothEnabled ? .green : .red)
                
                Text(viewModel.isBluetoothEnabled ? "Ready" : "Bluetooth Off")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(
                Capsule()
                    .fill(Color(.tertiarySystemGroupedBackground))
            )
            
            // Scanning indicator
            if viewModel.isScanning {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.7)
                    
                    Text("Scanning...")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    Capsule()
                        .fill(Color(.tertiarySystemGroupedBackground))
                )
            }
            
            Spacer()
            
            // Scan button
            Button(action: {
                if viewModel.isScanning {
                    viewModel.stopScanning()
                } else {
                    viewModel.startScanning()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                        .font(.system(size: 14, weight: .semibold))
                    
                    Text(viewModel.isScanning ? "Stop" : "Scan")
                        .font(.system(size: 14, weight: .semibold))
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(viewModel.isScanning ? Color.red : Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    Color(.secondarySystemGroupedBackground)
                        .opacity(0.95)
                )
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
    }
    
    private var deviceListView: some View {
        List {
            Section(header: listHeader) {
                ForEach(viewModel.filteredDevices) { device in
                    NavigationLink(destination: DeviceDetailView(device: device)) {
                        DeviceRowView(device: device)
                    }
                    .contextMenu {
                        deviceContextMenu(for: device)
                    }
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
        .refreshable {
            viewModel.refreshDevices()
        }
    }
    
    private var listHeader: some View {
        HStack {
            Text("Nearby Devices")
            
            Spacer()
            
            if !viewModel.devices.isEmpty && viewModel.filteredDevices.count < viewModel.devices.count {
                Text("\(viewModel.filteredDevices.count) of \(viewModel.devices.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            if !viewModel.isBluetoothEnabled {
                bluetoothDisabledView
            } else if viewModel.isScanning {
                scanningEmptyView
            } else if !viewModel.devices.isEmpty && viewModel.filteredDevices.isEmpty {
                filteredEmptyView
            } else {
                noDevicesEmptyView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
    }
    
    private var bluetoothDisabledView: some View {
        VStack(spacing: 24) {
            // Visual indicator
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 130, height: 130)
                
                Circle()
                    .fill(Color.red.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "bluetooth.slash")
                    .font(.system(size: 42, weight: .light))
                    .foregroundColor(.red)
            }
            
            VStack(spacing: 8) {
                Text("Bluetooth is Disabled")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Please enable Bluetooth in your device settings to scan for nearby devices.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                // On iOS, this will direct the user to enable Bluetooth in Settings
                guard let url = URL(string: "App-Prefs:root=Bluetooth") else { return }
                UIApplication.shared.open(url)
            }) {
                HStack {
                    Image(systemName: "gear")
                    Text("Open Settings")
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var scanningEmptyView: some View {
        VStack(spacing: 30) {
            // Animated scanning visual
            ZStack {
                // Outer ripple circles
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(Color.blue.opacity(0.3 - Double(i) * 0.1), lineWidth: 2)
                        .frame(width: CGFloat(120 + i * 40), height: CGFloat(120 + i * 40))
                        .scaleEffect(1)
                        .opacity(0.7)
                }
                
                // Center circle with radar animation
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 36))
                    .foregroundColor(.blue)
            }
            
            VStack(spacing: 10) {
                Text("Scanning for Devices...")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Please wait while we search for nearby devices")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.leading, 8)
                }
            }
            
            VStack(spacing: 6) {
                Text("Make sure your Bluetooth devices are turned on and in pairing mode.")
                    .font(.callout)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                
                Button(action: {
                    viewModel.stopScanning()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewModel.startScanning()
                    }
                }) {
                    Text("Restart Scan")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                }
                .padding(.top, 8)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var filteredEmptyView: some View {
        VStack(spacing: 24) {
            // Visual indicator
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 130, height: 130)
                
                Circle()
                    .stroke(Color.orange.opacity(0.2), lineWidth: 2)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(.orange)
            }
            
            VStack(spacing: 8) {
                Text("No Named Devices")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Found \(viewModel.devices.count) devices, but they are being filtered because they have generic names.")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                viewModel.hideUnnamedDevices = false
            }) {
                HStack {
                    Image(systemName: "eye")
                    Text("Show All Devices")
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20)
    }
    
    private var noDevicesEmptyView: some View {
        VStack(spacing: 24) {
            // Visual indicator
            ZStack {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 130, height: 130)
                
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "antenna.radiowaves.left.and.right.slash")
                    .font(.system(size: 38, weight: .light))
                    .foregroundColor(.gray)
            }
            
            VStack(spacing: 8) {
                Text("No Devices Found")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Start scanning to discover nearby Bluetooth devices")
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
            }
            
            Button(action: {
                viewModel.startScanning()
            }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Start Scanning")
                }
                .fontWeight(.semibold)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(20)
                .shadow(color: Color.blue.opacity(0.3), radius: 4, x: 0, y: 2)
            }
            
            Text("Tip: Make sure your devices are in pairing mode")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
    }
    
    // MARK: - Helper Functions
    
    private func deviceContextMenu(for device: Device) -> some View {
        Group {
            if device.isConnected {
                Button(action: {
                    viewModel.disconnect(from: device)
                }) {
                    Label("Disconnect", systemImage: "wifi.slash")
                }
            } else {
                Button(action: {
                    viewModel.connect(to: device)
                }) {
                    Label("Connect", systemImage: "wifi")
                }
            }
            
            Button(action: {
                viewModel.toggleSaveDevice(device)
            }) {
                if device.isSaved {
                    Label("Remove", systemImage: "bookmark.slash")
                } else {
                    Label("Save", systemImage: "bookmark")
                }
            }
        }
    }
}

// MARK: - Device Row Component
struct DeviceRowView: View {
    let device: Device
    
    var body: some View {
        HStack(spacing: 14) {
            // Device icon with background gradient
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [deviceTypeBackgroundColor.opacity(0.7), deviceTypeBackgroundColor]),
                            startPoint: .topLeading, 
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .shadow(color: deviceTypeBackgroundColor.opacity(0.3), radius: 3, x: 0, y: 2)
                
                Image(systemName: device.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            // Device info
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Text(device.name)
                        .font(.headline)
                    
                    // Status indicators
                    HStack(spacing: 4) {
                        if device.isConnected {
                            statusPill(text: "Connected", color: .green, icon: "link")
                        }
                        
                        if device.isSaved {
                            statusPill(text: "Saved", color: .blue, icon: "bookmark")
                        }
                    }
                }
                
                HStack(spacing: 12) {
                    // Signal strength indicator
                    HStack(spacing: 3) {
                        Image(systemName: rssiIcon(for: device.rssi))
                            .font(.system(size: 10))
                            .foregroundColor(signalColor(for: device.rssi))
                        
                        Text(device.signalStrength.description)
                            .font(.caption)
                            .foregroundColor(signalColor(for: device.rssi))
                    }
                    
                    // Last seen indicator
                    if let lastSeen = device.lastSeen {
                        HStack(spacing: 3) {
                            Image(systemName: "clock")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            
                            Text(timeAgo(lastSeen))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // RSSI value
                    Text("\(device.rssi ?? 0) dBm")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(minWidth: 60, alignment: .trailing)
                }
            }
            
            Spacer()
            
            // Signal bars
            HStack(spacing: 2) {
                ForEach(0..<4) { i in
                    RoundedRectangle(cornerRadius: 1.5)
                        .frame(width: 3, height: 8 + CGFloat(i * 3))
                        .foregroundColor(signalBarColor(for: device.signalStrength, bar: i))
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Views
    
    private func statusPill(text: String, color: Color, icon: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 8))
            
            Text(text)
                .font(.system(size: 9, weight: .medium))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(6)
    }
    
    // MARK: - Helper Functions
    
    private var deviceTypeBackgroundColor: Color {
        switch device.type {
        case .headphones: return .blue
        case .speaker: return .purple
        case .watch: return .green
        case .keyboard, .mouse: return .orange
        case .phone, .tablet: return .pink
        case .laptop, .computer: return .indigo
        case .unknown: return .gray
        }
    }
    
    private func signalBarColor(for strength: SignalStrength, bar: Int) -> Color {
        let isActive: Bool
        
        switch strength {
        case .excellent:
            isActive = true
        case .good:
            isActive = bar < 3
        case .fair:
            isActive = bar < 2
        case .poor:
            isActive = bar < 1
        }
        
        return isActive ? Color(strength.color) : Color(.systemGray5)
    }
    
    private func signalColor(for rssi: Int?) -> Color {
        guard let rssi = rssi else { return .gray }
        
        if rssi > -60 {
            return .green
        } else if rssi > -75 {
            return .blue
        } else if rssi > -90 {
            return .orange
        } else {
            return .red
        }
    }
    
    private func rssiIcon(for rssi: Int?) -> String {
        guard let rssi = rssi else { return "wifi.slash" }
        
        if rssi > -60 {
            return "wifi"
        } else if rssi > -75 {
            return "wifi"
        } else if rssi > -90 {
            return "wifi.exclamationmark"
        } else {
            return "wifi.slash"
        }
    }
    
    private func timeAgo(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "1d ago" : "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1h ago" : "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1m ago" : "\(minute)m ago"
        } else {
            return "Now"
        }
    }
}

struct DeviceListView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceListView()
    }
} 


