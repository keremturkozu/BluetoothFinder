import SwiftUI
import CoreLocation

struct SavedDevicesView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @StateObject private var viewModel = SavedDevicesViewModel()
    @State private var showingDeleteAlert = false
    @State private var deviceToDelete: Device?
    @State private var showSettingsSheet = false
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.isLoading {
                    loadingView
                } else if viewModel.savedDevices.isEmpty {
                    emptyStateView
                } else {
                    deviceListView
                }
            }
            .navigationTitle("Saved Devices")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .alert("Delete Device", isPresented: $showingDeleteAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    if let device = deviceToDelete {
                        viewModel.removeDevice(device)
                    }
                }
            } message: {
                if let device = deviceToDelete {
                    Text("Are you sure you want to delete \(device.name)? This action cannot be undone.")
                } else {
                    Text("Are you sure you want to delete this device? This action cannot be undone.")
                }
            }
            .sheet(item: $viewModel.selectedDevice) { device in
                DeviceDetailView(device: device)
            }
            .sheet(isPresented: $showSettingsSheet) {
                SettingsView()
            }
            .onAppear {
                viewModel.injectDeviceManager(deviceManager)
            }
        }
    }
    
    // MARK: - Helper Views
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("Loading saved devices...")
                .padding(.top)
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.slash")
                .font(.system(size: 60))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No Saved Devices")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Your saved devices will appear here. To save a device, go to the Devices tab and mark a device as saved.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
    
    private var deviceListView: some View {
        List {
            ForEach(viewModel.savedDevices) { device in
                SavedDeviceRow(device: device, deviceManager: deviceManager)
                    .contentShape(Rectangle())
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
                        
                        Button(action: { viewModel.updateDeviceLocation(device) }) {
                            Label("Update Location", systemImage: "location.fill")
                        }
                        
                        Button(action: {
                            deviceToDelete = device
                            showingDeleteAlert = true
                        }) {
                            Label("Delete Device", systemImage: "trash")
                        }
                    }
            }
            .onDelete { indexSet in
                viewModel.deleteDevices(at: indexSet)
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
}

// MARK: - Saved Device Row
struct SavedDeviceRow: View {
    let device: Device
    let deviceManager: DeviceManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Device icon
            ZStack {
                Circle()
                    .fill(deviceTypeColor)
                    .frame(width: 48, height: 48)
                    .shadow(radius: 2)
                
                Image(systemName: deviceTypeIcon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            
            // Device info
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                
                HStack(spacing: 12) {
                    // Last seen info
                    if device.lastSeen != nil && device.lastSeen != Date.distantPast {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            
                            Text(timeAgo(from: device.lastSeen))
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    // Connection status
                    if device.isConnected {
                        Text("Connected")
                            .font(.caption)
                            .padding(4)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    }
                }
                
                // Location info
                if let location = device.location {
                    Text(formatLocationDistance(location))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Signal strength indicator if available
            if let rssi = device.rssi {
                VStack(spacing: 2) {
                    Image(systemName: signalIcon(for: rssi))
                        .foregroundColor(signalColor(for: rssi))
                    
                    Text("\(rssi) dBm")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Properties & Methods
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
    
    private func signalIcon(for rssi: Int) -> String {
        if rssi > -50 {
            return "wifi.3"
        } else if rssi > -65 {
            return "wifi.2"
        } else if rssi > -80 {
            return "wifi.1"
        } else {
            return "wifi.exclamationmark"
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
    
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day)d ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)h ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)m ago"
        } else {
            return "Just now"
        }
    }
    
    private func formatLocationDistance(_ location: CLLocation) -> String {
        if let userLocation = deviceManager.locationService.currentLocation {
            let distance = location.distance(from: userLocation)
            return distance < 1000 
                ? String(format: "%.0f meters away", distance) 
                : String(format: "%.2f km away", distance / 1000)
        } else {
            return "Location saved"
        }
    }
}

#Preview {
    SavedDevicesView()
        .environmentObject(DeviceManager())
} 
