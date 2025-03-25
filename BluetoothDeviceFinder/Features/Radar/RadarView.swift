import SwiftUI
import CoreLocation

struct RadarView: View {
    @ObservedObject var viewModel: RadarViewModel
    @EnvironmentObject var deviceManager: DeviceManager
    @Environment(\.colorScheme) var colorScheme
    
    @State private var selectedDevice: Device?
    @State private var radarAngle: Double = 0
    @State private var pulsateAnimation = false
    @State private var scanningInProgress = false
    
    // Timer for rotation animation
    private let timer = Timer.publish(every: 0.04, on: .main, in: .common).autoconnect()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 8) {
                Text("Radar")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.top, 16)
                
                if deviceManager.devices.isEmpty && !deviceManager.isScanning {
                    emptyStateView
                } else {
                    VStack(spacing: 12) {
                        // Radar visualization
                        radarVisualization
                        
                        // Scan button
                        Button(action: {
                            viewModel.toggleScanning()
                        }) {
                            HStack {
                                Image(systemName: viewModel.isScanning ? "stop.circle" : "play.circle")
                                Text(viewModel.isScanning ? "Stop Scanning" : "Start Scanning")
                            }
                            .font(.headline)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .foregroundColor(.white)
                            .background(viewModel.isScanning ? Color.red : Color.green)
                            .cornerRadius(10)
                        }
                        .padding(.bottom, 8)
                        
                        // Device list
                        deviceListView
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(item: $selectedDevice) { device in
            DeviceDetailView(device: device)
        }
        .onAppear {
            viewModel.injectDeviceManager(deviceManager)
            viewModel.startScanning()
        }
        .onDisappear {
            viewModel.stopScanning()
        }
        .onReceive(timer) { _ in
            if deviceManager.isScanning {
                withAnimation {
                    radarAngle = (radarAngle + 2).truncatingRemainder(dividingBy: 360)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 70))
                .foregroundColor(.gray.opacity(0.7))
            
            Text("No Devices Found")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start scanning to find nearby devices")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                viewModel.startScanning()
            }) {
                HStack {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                    Text("Start Scanning")
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(15)
                .shadow(radius: 3)
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }
    
    private var radarBackgroundColor: Color {
        colorScheme == .dark ? Color.black : Color(UIColor.systemGray5).opacity(0.8)
    }
    
    private var radarLineColor: Color {
        colorScheme == .dark ? Color.green : Color.green.opacity(0.8)
    }
    
    private var radarRingColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.3) : Color.green.opacity(0.4)
    }
    
    private var radarInnerRingColor: Color {
        colorScheme == .dark ? Color.green.opacity(0.1) : Color.green.opacity(0.2)
    }
    
    private var radarVisualization: some View {
        ZStack {
            // Radar background
            Circle()
                .stroke(radarRingColor, lineWidth: 2)
                .background(Circle().fill(radarBackgroundColor))
                .overlay(
                    Circle()
                        .stroke(radarInnerRingColor, lineWidth: 1)
                        .scaleEffect(0.75)
                )
                .overlay(
                    Circle()
                        .stroke(radarInnerRingColor, lineWidth: 1)
                        .scaleEffect(0.5)
                )
                .overlay(
                    Circle()
                        .stroke(radarInnerRingColor, lineWidth: 1)
                        .scaleEffect(0.25)
                )
                .frame(width: 280, height: 280)
            
            // Radar line
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [radarLineColor, radarLineColor.opacity(0)]),
                        startPoint: .center,
                        endPoint: .trailing
                    )
                )
                .frame(width: 140, height: 3)
                .offset(x: 70)
                .rotationEffect(Angle(degrees: radarAngle))
            
            // Center dot
            Circle()
                .fill(radarLineColor)
                .frame(width: 8, height: 8)
            
            // Device dots on radar
            ForEach(deviceManager.devices) { device in
                DeviceBlip(device: device, viewModel: viewModel, maxRadius: 140)
                    .onTapGesture {
                        selectedDevice = device
                    }
            }
            
            // Scanning effect when scanning is in progress
            if deviceManager.isScanning {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(radarLineColor.opacity(0.5), lineWidth: 4)
                    .frame(width: 280, height: 280)
                    .rotationEffect(Angle(degrees: radarAngle))
            }
        }
        .padding(.top, 10)
    }
    
    private var deviceListView: some View {
        VStack {
            Text("Nearby Devices")
                .font(.headline)
                .padding(.vertical, 8)
            
            if deviceManager.devices.isEmpty {
                Text("No devices found")
                    .foregroundStyle(.gray)
                    .italic()
                    .padding()
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        // Sort devices by signal strength (RSSI)
                        ForEach(deviceManager.devices.sorted { ($0.rssi ?? -100) > ($1.rssi ?? -100) }) { device in
                            deviceRow(device: device)
                                .padding(8)
                                .background(Color(UIColor.systemBackground))
                                .cornerRadius(8)
                                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                                .padding(.horizontal)
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }
    
    private func deviceRow(device: Device) -> some View {
        Button(action: {
            selectedDevice = device
        }) {
            HStack {
                Circle()
                    .fill(signalColor(for: device.rssi))
                    .frame(width: 10, height: 10)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        // Gösterimi dbm yerine mesafe olarak değiştir
                        Text("\(formatDistance(calculateDistance(rssi: device.rssi))) away")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let batteryLevel = device.batteryLevel {
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Battery: \(batteryLevel)%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemBackground))
            .cornerRadius(10)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func signalColor(for rssi: Int?) -> Color {
        guard let rssi = rssi else { return .gray }
        if rssi > -60 {
            return .green
        } else if rssi > -80 {
            return .orange
        } else {
            return .red
        }
    }
    
    // Calculate approximate distance based on RSSI
    private func calculateDistance(rssi: Int?) -> Double {
        // Simple distance calculation based on RSSI
        // Using a simplified path loss model: distance = 10^((TxPower - RSSI)/(10 * n))
        // Where TxPower is the RSSI at 1 meter (typically around -59 to -69) and n is the path loss exponent (typically 2-4)
        
        guard let rssi = rssi else { return 10.0 } // Default to 10 meters if no RSSI
        
        let txPower = -59 // RSSI at 1 meter (can be calibrated)
        let n = 2.5 // Path loss exponent (environment dependent)
        
        return pow(10, (Double(txPower - rssi) / (10 * n)))
    }
    
    // Kullanıcı dostu mesafe formatı
    private func formatDistance(_ distance: Double) -> String {
        if distance < 1 {
            // 1 metreden küçük mesafeler için ondalıklı değer
            return String(format: "%.1f m", distance)
        } else if distance < 10 {
            // 10 metreye kadar bir ondalık göster
            return String(format: "%.1f m", distance)
        } else {
            // 10 metre ve üzeri tam sayı olarak göster
            return "\(Int(distance)) m"
        }
    }
}

// Device blip (dot) on radar
struct DeviceBlip: View {
    let device: Device
    let viewModel: RadarViewModel
    let maxRadius: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        let distance = calculateDisplayDistance()
        let angle = viewModel.angleForDevice(device)
        let position = calculatePosition(angle: angle, distance: distance, maxRadius: maxRadius)
        
        ZStack {
            deviceTypeCircle
                .position(position)
            
            Text(device.name)
                .font(.caption2)
                .foregroundColor(.white)
                .padding(4)
                .background(colorScheme == .dark ? Color.black.opacity(0.7) : Color.black.opacity(0.8))
                .cornerRadius(4)
                .position(x: position.x, y: position.y - 25)
        }
    }
    
    private var deviceTypeCircle: some View {
        Circle()
            .fill(deviceTypeColor)
            .frame(width: 15, height: 15)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
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
    
    private func calculateDisplayDistance() -> CGFloat {
        let normalizedDistance = viewModel.normalizedDistance(for: device)
        return CGFloat(normalizedDistance) * maxRadius * 0.7 // Daha belirgin bir radar alanı kullanmak için ölçeği küçültüyorum
    }
    
    private func calculatePosition(angle: Double, distance: CGFloat, maxRadius: CGFloat) -> CGPoint {
        let centerX = maxRadius
        let centerY = maxRadius
        
        let radians = angle * .pi / 180.0
        let x = centerX + distance * CGFloat(sin(radians))
        let y = centerY - distance * CGFloat(cos(radians))
        
        return CGPoint(x: x, y: y)
    }
}

#Preview {
    RadarView(viewModel: RadarViewModel())
        .environmentObject(DeviceManager())
} 