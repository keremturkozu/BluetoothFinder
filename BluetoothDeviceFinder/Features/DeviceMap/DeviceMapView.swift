import SwiftUI
import MapKit

struct DeviceMapView: View {
    @EnvironmentObject private var deviceManager: DeviceManager
    @StateObject private var viewModel = DeviceMapViewModel()
    @State private var mapRegion = MKCoordinateRegion()
    @State private var userTrackingMode: MapUserTrackingMode = .follow
    @State private var showingLocationAlert = false
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $mapRegion,
                showsUserLocation: true,
                userTrackingMode: $userTrackingMode,
                annotationItems: viewModel.filteredAnnotations) { annotation in
                MapAnnotation(coordinate: annotation.coordinate) {
                    VStack {
                        deviceAnnotationView(for: annotation)
                    }
                    .onTapGesture {
                        viewModel.selectDevice(annotation.device)
                    }
                }
            }
            .ignoresSafeArea(edges: .top)
            
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 10) {
                        mapControlButton(systemName: "location", action: centerOnUserLocation)
                        
                        mapControlButton(systemName: "arrow.clockwise", action: refreshDeviceLocations)
                        
                        // Zoom in button
                        mapControlButton(systemName: "plus.magnifyingglass") {
                            zoomMap(zoomIn: true)
                        }
                        
                        // Zoom out button
                        mapControlButton(systemName: "minus.magnifyingglass") {
                            zoomMap(zoomIn: false)
                        }
                        
                        // Filtreleme kontrolü
                        mapControlButton(systemName: viewModel.hideUnnamedDevices ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") {
                            viewModel.hideUnnamedDevices.toggle()
                        }
                    }
                    .padding(8)
                    .background(Color(.systemBackground).opacity(0.8))
                    .cornerRadius(10)
                    .shadow(radius: 2)
                    .padding()
                }
                
                Spacer()
                
                if !viewModel.mapAnnotations.isEmpty {
                    deviceInfoOverlay
                }
            }
            
            if deviceManager.devices.isEmpty && !deviceManager.isScanning {
                emptyStateOverlay
            }
        }
        .onAppear {
            initializeMap()
            viewModel.injectDeviceManager(deviceManager)
        }
        .onChange(of: deviceManager.devices) { _ in
            viewModel.updateAnnotations(from: deviceManager.devices)
        }
        .onChange(of: deviceManager.locationService.currentLocation) { newLocation in
            if let location = newLocation {
                updateMapRegion(with: location.coordinate)
            }
        }
        .alert("Location Services Disabled", isPresented: $showingLocationAlert) {
            Button("Go to Settings", action: openSettings)
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please enable location services in Settings to see your position on the map.")
        }
        .sheet(item: $viewModel.selectedDevice) { device in
            DeviceDetailView(device: device)
        }
    }
    
    private var deviceInfoOverlay: some View {
        VStack(spacing: 0) {
            // Başlık kısmı
            HStack {
                Text("Device Locations")
                    .font(.headline)
                
                Spacer()
                
                // Filtre durum göstergesi
                if viewModel.hideUnnamedDevices && viewModel.mapAnnotations.count > viewModel.filteredAnnotations.count {
                    Text("\(viewModel.filteredAnnotations.count) of \(viewModel.mapAnnotations.count)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue)
            .foregroundColor(.white)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(viewModel.filteredAnnotations) { annotation in
                        deviceStatusButton(device: annotation.device)
                    }
                }
                .padding()
            }
            .background(Color(.systemBackground).opacity(0.9))
        }
        .cornerRadius(10)
        .shadow(radius: 3)
        .padding()
    }
    
    private func deviceStatusButton(device: Device) -> some View {
        Button(action: {
            centerMap(on: device)
            viewModel.selectDevice(device)
        }) {
            HStack(spacing: 8) {
                Image(systemName: deviceSystemImage(for: device))
                    .foregroundColor(deviceColor(for: device))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(viewModel.distanceText(for: device))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func deviceAnnotationView(for annotation: DeviceAnnotation) -> some View {
        ZStack {
            Circle()
                .fill(Color.white)
                .frame(width: 44, height: 44)
                .shadow(radius: 3)
            
            Image(systemName: deviceSystemImage(for: annotation.device))
                .font(.system(size: 20))
                .foregroundColor(deviceColor(for: annotation.device))
        }
    }
    
    private func deviceSystemImage(for device: Device) -> String {
        switch device.type {
        case .watch:
            return "applewatch"
        case .headphones:
            return "headphones"
        case .phone:
            return "iphone"
        case .tablet:
            return "ipad"
        case .computer:
            return "desktopcomputer"
        case .laptop:
            return "laptopcomputer"
        case .speaker:
            return "hifispeaker"
        case .keyboard:
            return "keyboard"
        case .mouse:
            return "mouse"
        case .unknown:
            return "cube.box"
        }
    }
    
    private func deviceColor(for device: Device) -> Color {
        guard let rssi = device.rssi else { return .red }
        
        if rssi > -60 {
            return .green
        } else if rssi > -80 {
            return .orange
        } else {
            return .red
        }
    }
    
    private var emptyStateOverlay: some View {
        VStack(spacing: 20) {
            Image(systemName: "map")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No Devices on Map")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start scanning to find devices and display them on the map")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: {
                deviceManager.startScanning()
            }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Start Scanning")
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground).opacity(0.9))
        .cornerRadius(15)
        .shadow(radius: 5)
        .padding(30)
    }
    
    private func mapControlButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.blue)
                .frame(width: 40, height: 40)
                .background(Color(.systemBackground))
                .clipShape(Circle())
                .shadow(radius: 2)
        }
    }
    
    private func initializeMap() {
        if let userLocation = deviceManager.locationService.currentLocation {
            updateMapRegion(with: userLocation.coordinate)
        } else {
            // Default to a reasonable zoom level if no location
            mapRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 37.3315, longitude: -122.0324),
                span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
            )
            
            // Check if location services are enabled
            if deviceManager.locationService.authorizationStatus == .denied {
                showingLocationAlert = true
            }
        }
        
        // Update map annotations based on current devices
        viewModel.injectDeviceManager(deviceManager)
        viewModel.updateAnnotations(from: deviceManager.devices)
    }
    
    private func centerOnUserLocation() {
        if let userLocation = deviceManager.locationService.currentLocation {
            updateMapRegion(with: userLocation.coordinate)
        } else {
            showingLocationAlert = true
        }
    }
    
    private func refreshDeviceLocations() {
        // First refresh the annotations
        viewModel.updateAnnotations(from: deviceManager.devices)
        
        // Then update the map region to include all devices
        if let userLocation = deviceManager.locationService.currentLocation, !viewModel.mapAnnotations.isEmpty {
            fitAllAnnotationsInView(userLocation: userLocation)
        }
    }
    
    private func centerMap(on device: Device) {
        guard let location = device.lastLocation else { return }
        
        let coordinate = CLLocationCoordinate2D(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
        
        updateMapRegion(with: coordinate, span: 0.01)
    }
    
    private func updateMapRegion(with coordinate: CLLocationCoordinate2D, span: Double = 0.02) {
        mapRegion = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
    }
    
    private func zoomMap(zoomIn: Bool) {
        var span = mapRegion.span
        let factor: Double = zoomIn ? 0.5 : 2.0
        
        span.latitudeDelta *= factor
        span.longitudeDelta *= factor
        
        // Limit zoom levels
        span.latitudeDelta = min(max(span.latitudeDelta, 0.001), 150.0)
        span.longitudeDelta = min(max(span.longitudeDelta, 0.001), 150.0)
        
        mapRegion.span = span
    }
    
    private func fitAllAnnotationsInView(userLocation: CLLocation) {
        guard !viewModel.mapAnnotations.isEmpty else { return }
        
        // Include user location as a point to consider
        var minLat = userLocation.coordinate.latitude
        var maxLat = userLocation.coordinate.latitude
        var minLon = userLocation.coordinate.longitude
        var maxLon = userLocation.coordinate.longitude
        
        // Find min/max coordinates from all annotations
        for annotation in viewModel.mapAnnotations {
            minLat = min(minLat, annotation.coordinate.latitude)
            maxLat = max(maxLat, annotation.coordinate.latitude)
            minLon = min(minLon, annotation.coordinate.longitude)
            maxLon = max(maxLon, annotation.coordinate.longitude)
        }
        
        // Calculate center
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Calculate span (with padding)
        let padding = 1.2 // Add 20% padding
        let latDelta = max(0.01, (maxLat - minLat) * padding)
        let lonDelta = max(0.01, (maxLon - minLon) * padding)
        
        // Update map region
        mapRegion = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
        )
    }
    
    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    DeviceMapView()
        .environmentObject(DeviceManager())
} 
