import SwiftUI

struct DeviceListView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @StateObject private var viewModel = DeviceListViewModel()
    @State private var selectedDevice: Device?
    
    var body: some View {
        NavigationView {
            ZStack {
                if viewModel.devices.isEmpty {
                    emptyStateView
                } else {
                    deviceListView
                }
            }
            .navigationTitle("Device Finder")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    scanButton
                }
            }
            .alert(item: errorBinding) { errorWrapper in
                Alert(
                    title: Text("Error"),
                    message: Text(errorWrapper.message),
                    dismissButton: .default(Text("OK"))
                )
            }
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device)
            }
            .onAppear {
                viewModel.injectDeviceManager(deviceManager)
            }
        }
    }
    
    // MARK: - Helper Views
    private var scanButton: some View {
        Button(action: {
            viewModel.toggleScanning()
        }) {
            HStack {
                Text(viewModel.isScanning ? "Stop" : "Scan")
                Image(systemName: viewModel.isScanning ? "stop.circle" : "antenna.radiowaves.left.and.right")
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 72))
                .foregroundColor(.gray)
            Text(viewModel.isScanning ? "Scanning for devices..." : "No devices found")
                .font(.headline)
            Text(viewModel.isScanning ? "Nearby Bluetooth devices will appear here" : "Tap Scan to start looking for devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            if viewModel.isScanning {
                ProgressView()
                    .padding()
            }
        }
    }
    
    private var deviceListView: some View {
        List {
            Section {
                ForEach(viewModel.devices) { device in
                    DeviceListItemView(device: device)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedDevice = device
                        }
                }
            } header: {
                if viewModel.isScanning {
                    HStack {
                        Text("Scanning...")
                        Spacer()
                        ProgressView()
                    }
                } else {
                    Text("Found Devices")
                }
            }
        }
        .listStyle(InsetGroupedListStyle())
    }
    
    // MARK: - Bindings
    private var errorBinding: Binding<ErrorWrapper?> {
        Binding<ErrorWrapper?>(
            get: {
                guard let errorMessage = viewModel.errorMessage else { return nil }
                return ErrorWrapper(id: UUID(), message: errorMessage)
            },
            set: { _ in
                viewModel.errorMessage = nil
            }
        )
    }
    
    // MARK: - Helper Types
    struct ErrorWrapper: Identifiable {
        let id: UUID
        let message: String
    }
}

struct DeviceListItemView: View {
    let device: Device
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)
                
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(signalColor)
                    
                    Text(device.distanceDescription ?? "Unknown")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if let batteryLevel = device.batteryLevel {
                        Spacer()
                        
                        HStack(spacing: 2) {
                            Image(systemName: batteryIcon)
                                .foregroundColor(batteryColor)
                            Text("\(batteryLevel)%")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                if let location = device.location {
                    Text("Last seen: \(formatDate(device.lastSeen))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14))
        }
    }
    
    // MARK: - Helper Methods
    private var signalColor: Color {
        guard let rssi = device.rssi else { return .gray }
        
        if rssi > -50 {
            return .green
        } else if rssi > -65 {
            return .yellow
        } else if rssi > -80 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var batteryIcon: String {
        guard let batteryLevel = device.batteryLevel else { return "battery.0" }
        
        if batteryLevel > 75 {
            return "battery.100"
        } else if batteryLevel > 50 {
            return "battery.75"
        } else if batteryLevel > 25 {
            return "battery.50"
        } else {
            return "battery.25"
        }
    }
    
    private var batteryColor: Color {
        guard let batteryLevel = device.batteryLevel else { return .gray }
        
        if batteryLevel > 50 {
            return .green
        } else if batteryLevel > 25 {
            return .yellow
        } else {
            return .red
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

#Preview {
    DeviceListView()
} 