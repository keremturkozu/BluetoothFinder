import SwiftUI
import MapKit

struct DeviceDetailView: View {
    let device: Device
    @Environment(\.presentationMode) var presentationMode
    @State private var region: MKCoordinateRegion?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    deviceInfoCard
                    
                    if let location = device.location {
                        deviceLocationView(location: location)
                    } else {
                        noLocationView
                    }
                }
                .padding()
            }
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let location = device.location {
                region = MKCoordinateRegion(
                    center: location.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
        }
    }
    
    // MARK: - Helper Views
    private var deviceInfoCard: some View {
        VStack(spacing: 16) {
            deviceIcon
            
            VStack(spacing: 8) {
                InfoRow(
                    title: "Signal Strength",
                    icon: "antenna.radiowaves.left.and.right",
                    value: device.distanceDescription ?? "Unknown",
                    iconColor: signalColor
                )
                
                InfoRow(
                    title: "Battery",
                    icon: batteryIcon,
                    value: device.batteryDescription,
                    iconColor: batteryColor
                )
                
                InfoRow(
                    title: "Last Seen",
                    icon: "clock",
                    value: formatDate(device.lastSeen),
                    iconColor: .blue
                )
                
                InfoRow(
                    title: "Status",
                    icon: device.isConnected ? "checkmark.circle" : "xmark.circle",
                    value: device.isConnected ? "Connected" : "Disconnected",
                    iconColor: device.isConnected ? .green : .gray
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
    }
    
    private var deviceIcon: some View {
        ZStack {
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 80, height: 80)
            
            Image(systemName: "laptopcomputer")
                .font(.system(size: 30))
                .foregroundColor(.blue)
        }
    }
    
    private func deviceLocationView(location: CLLocation) -> some View {
        VStack(spacing: 0) {
            HStack {
                Label("Device Location", systemImage: "mappin.and.ellipse")
                    .font(.headline)
                Spacer()
                Button(action: {
                    openInMaps(location: location)
                }) {
                    Text("Directions")
                        .font(.subheadline)
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12, corners: [.topLeft, .topRight])
            
            if let region = region {
                Map(coordinateRegion: .constant(region), annotationItems: [LocationPin(coordinate: location.coordinate)]) { annotation in
                    MapMarker(coordinate: annotation.coordinate, tint: .blue)
                }
                .frame(height: 200)
                .cornerRadius(12, corners: [.bottomLeft, .bottomRight])
                .padding(.bottom)
            }
        }
    }
    
    private var noLocationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "location.slash")
                .font(.system(size: 40))
                .foregroundColor(.gray)
            
            Text("No Location Data")
                .font(.headline)
            
            Text("The location of this device has not been recorded yet.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
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
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func openInMaps(location: CLLocation) {
        let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: location.coordinate))
        mapItem.name = device.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}

struct InfoRow: View {
    let title: String
    let icon: String
    let value: String
    let iconColor: Color
    
    var body: some View {
        HStack {
            Label {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
            }
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}

struct LocationPin: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Extensions
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    DeviceDetailView(
        device: Device(
            name: "MacBook Pro",
            identifier: "ABCDEF",
            location: CLLocation(latitude: 40.7128, longitude: -74.0060),
            batteryLevel: 75,
            rssi: -65,
            isConnected: true
        )
    )
} 