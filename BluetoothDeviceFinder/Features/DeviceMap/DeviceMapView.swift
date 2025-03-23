import SwiftUI
import MapKit

struct DeviceMapView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @StateObject private var viewModel = DeviceMapViewModel()
    @State private var selectedDevice: Device?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.3320, longitude: -122.0312),
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                mapView
                
                if viewModel.isLoading {
                    loadingView
                }
                
                VStack {
                    Spacer()
                    scanButtonView
                }
                .padding()
            }
            .navigationTitle("Device Map")
            .sheet(item: $selectedDevice) { device in
                DeviceDetailView(device: device)
            }
            .onAppear {
                viewModel.injectDeviceManager(deviceManager)
                viewModel.startUpdatingLocation()
            }
            .onDisappear {
                viewModel.stopUpdatingLocation()
            }
        }
    }
    
    // MARK: - Helper Views
    private var mapView: some View {
        Map(coordinateRegion: $region, showsUserLocation: true, annotationItems: deviceAnnotations) { annotation in
            MapMarker(coordinate: annotation.coordinate, tint: .blue)
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var loadingView: some View {
        VStack {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            Text("Getting your location...")
                .font(.caption)
                .padding(.top, 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemBackground).opacity(0.8))
        )
    }
    
    private var scanButtonView: some View {
        Button(action: {
            viewModel.isScanning ? viewModel.stopScanning() : viewModel.startScanning()
        }) {
            HStack {
                Image(systemName: viewModel.isScanning ? "stop.circle.fill" : "antenna.radiowaves.left.and.right")
                Text(viewModel.isScanning ? "Stop Scanning" : "Start Scanning")
            }
            .font(.headline)
            .padding()
            .background(viewModel.isScanning ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(40)
            .shadow(radius: 5)
        }
    }
    
    // MARK: - Helper Properties
    private var deviceAnnotations: [DeviceLocationAnnotation] {
        viewModel.devices.compactMap { device in
            guard let location = device.location else { return nil }
            return DeviceLocationAnnotation(device: device, coordinate: location.coordinate)
        }
    }
}

struct DeviceMapAnnotation: View {
    let device: Device
    
    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Circle()
                    .fill(signalColor)
                    .frame(width: 40, height: 40)
                    .shadow(color: signalColor.opacity(0.5), radius: 4)
                
                Image(systemName: "laptopcomputer")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            Text(device.name)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(.systemBackground))
                .cornerRadius(8)
                .shadow(radius: 2)
                .padding(.top, 4)
        }
    }
    
    // MARK: - Helper Properties
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
}

struct DeviceLocationAnnotation: Identifiable {
    let id: UUID
    let device: Device
    let coordinate: CLLocationCoordinate2D
    
    init(device: Device, coordinate: CLLocationCoordinate2D) {
        self.id = device.id
        self.device = device
        self.coordinate = coordinate
    }
}

#Preview {
    DeviceMapView()
        .environmentObject(DeviceManager())
} 