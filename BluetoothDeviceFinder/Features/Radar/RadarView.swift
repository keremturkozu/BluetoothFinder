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
                // Header
                HStack {
                    Text("Radar")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // Filtreleme kontrolü
                    Menu {
                        Toggle(isOn: $viewModel.hideUnnamedDevices) {
                            Label("Hide unnamed devices", systemImage: "tag")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(viewModel.hideUnnamedDevices ? "Filtered" : "All Devices")
                                .font(.caption)
                                .fontWeight(.medium)
                            
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.title2)
                                .foregroundColor(.primary)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                // Hem deviceManager hem de viewModel'deki cihazları kontrol et
                if deviceManager.devices.isEmpty && !deviceManager.isScanning {
                    // Hiç cihaz yok
                    emptyStateView
                } else if viewModel.filteredDevices.isEmpty && !deviceManager.devices.isEmpty && viewModel.hideUnnamedDevices {
                    // Cihazlar var ama filtreleme nedeniyle gösterilmiyor
                    filteredEmptyStateView
                } else {
                    VStack(spacing: 12) {
                        // Radar visualization
                        radarVisualization
                            .padding(.bottom, 8)
                        
                        // Scan button
                        Button(action: {
                            if deviceManager.isScanning {
                                deviceManager.stopScanning()
                            } else {
                                deviceManager.startScanning()
                            }
                        }) {
                            HStack {
                                Image(systemName: deviceManager.isScanning ? "stop.circle" : "play.circle")
                                Text(deviceManager.isScanning ? "Stop Scanning" : "Start Scanning")
                            }
                            .font(.headline)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(deviceManager.isScanning ? Color.red : Color.green)
                                    .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 2)
                            )
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
            // ViewModel'i deviceManager ile bağla
            viewModel.injectDeviceManager(deviceManager)
            
            // Eğer hiç tarama yapılmadıysa ve cihazlar boşsa taramayı başlat
            if deviceManager.devices.isEmpty && !deviceManager.isScanning {
                deviceManager.startScanning()
            }
        }
        .onDisappear {
            // Görünüm kaybolduğunda taramayı durdurmayalım, diğer ekranlar da kullanabilir
            // deviceManager.stopScanning()
        }
        .onReceive(timer) { _ in
            // İster tarama yapılsın ister yapılmasın, animasyonu daima çalıştır
            withAnimation {
                radarAngle = (radarAngle + 2).truncatingRemainder(dividingBy: 360)
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
    
    private var filteredEmptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 70))
                .foregroundColor(.orange.opacity(0.8))
            
            Text("No Named Devices")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Found \(deviceManager.devices.count) devices, but they are being filtered because they have generic names.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
            
            Button(action: {
                viewModel.hideUnnamedDevices = false
            }) {
                HStack {
                    Image(systemName: "eye")
                    Text("Show All Devices")
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
            
            // Radar line - radarın her durumda dönmesini sağla
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
            
            // Device dots on radar - cihazların radar üzerinde düzgün görüntülenmesini sağla
            ForEach(Array(viewModel.filteredDevices.enumerated()), id: \.element.id) { index, device in
                let angleOffset = 36.0 * Double(index) // Her cihazı 36 derece aralıklarla dağıtalım (10 cihaz için tam çember)
                let angle = (viewModel.angleForDevice(device) + angleOffset).truncatingRemainder(dividingBy: 360)
                
                let baseDistance = viewModel.normalizedDistance(for: device)
                // Merkeze yakın olmalarını engellemek için minimum mesafe ekleyelim
                let distance = max(0.3, baseDistance)
                
                let radius = 140.0 * distance // Mesafe cinsinden yarıçapı hesapla
                
                // Trigonometrik dönüşüm, açı derece cinsinden, radyana çevirerek
                let radians = angle * .pi / 180.0
                let xOffset = radius * sin(radians)  // sin fonksiyonu kullanarak X koordinatı
                let yOffset = -radius * cos(radians) // cos fonksiyonu kullanarak Y koordinatı (eksi, çünkü Y yukarı yöndedir)
                
                // Cihaz noktası
                ZStack {
                    // Dış halka (sinyal gücü göstergesi)
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 20, height: 20)
                    
                    // İç nokta (cihaz)
                    Circle()
                        .fill(signalColor(for: device.rssi))
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 1)
                                .opacity(0.7)
                        )
                }
                .shadow(color: signalColor(for: device.rssi).opacity(0.6), radius: 3, x: 0, y: 0)
                .offset(x: xOffset, y: yOffset)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: xOffset)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: yOffset)
                .onTapGesture {
                    selectedDevice = device
                }
                
                // Cihaz etiketleri (isimleri)
                VStack(spacing: 2) {
                    Text(device.name.count > 15 ? String(device.name.prefix(12)) + "..." : device.name)
                        .font(.system(size: 10, weight: .medium))
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(4)
                    
                    // RSSI değeri
                    Text("\(device.rssi ?? 0) dBm")
                        .font(.system(size: 8))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color(signalColor(for: device.rssi)).opacity(0.3))
                        .foregroundColor(.white)
                        .cornerRadius(3)
                }
                .offset(x: xOffset, y: yOffset + 18) // İsim ve sinyal gücünü noktanın altında göster
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: xOffset)
                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: yOffset)
            }
            
            // Scanning pulse effect
            if deviceManager.isScanning {
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(radarLineColor.opacity(0.5), lineWidth: 4)
                    .frame(width: 280, height: 280)
                    .rotationEffect(Angle(degrees: radarAngle))
                
                // Pulse effect
                Circle()
                    .stroke(radarLineColor.opacity(0.15), lineWidth: 2)
                    .frame(width: 280, height: 280)
                    .scaleEffect(pulsateAnimation ? 1.0 : 0.97)
                    .animation(
                        Animation.easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                        value: pulsateAnimation
                    )
                    .onAppear {
                        pulsateAnimation = true
                    }
            }
        }
        .padding(.vertical, 20)
    }
    
    private var deviceListView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Nearby Devices")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // Filtered devices count - deviceManager'daki toplam cihaz sayısını göster
                if viewModel.hideUnnamedDevices && deviceManager.devices.count > viewModel.filteredDevices.count {
                    Text("\(viewModel.filteredDevices.count) of \(deviceManager.devices.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            
            Divider()
            
            if viewModel.filteredDevices.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 36))
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                    
                    Text("No devices found")
                        .font(.subheadline)
                        .foregroundStyle(.gray)
                    
                    if !deviceManager.isScanning {
                        Button("Start Scanning") {
                            deviceManager.startScanning()
                        }
                        .font(.caption)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .padding(.top, 5)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        // Sort devices by signal strength (RSSI)
                        ForEach(viewModel.filteredDevices.sorted { ($0.rssi ?? -100) > ($1.rssi ?? -100) }) { device in
                            deviceRow(device: device)
                                .padding(.vertical, 4)
                        }
                    }
                    .padding(8)
                }
                .frame(height: 180)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }
    
    private func deviceRow(device: Device) -> some View {
        HStack(spacing: 12) {
            // Signal strength indicator
            ZStack {
                Circle()
                    .fill(signalColor(for: device.rssi).opacity(0.15))
                    .frame(width: 40, height: 40)
                
                Image(systemName: deviceTypeIcon(for: device))
                    .font(.system(size: 16))
                    .foregroundColor(signalColor(for: device.rssi))
            }
            
            // Device info
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                
                HStack(spacing: 8) {
                    // Distance
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        
                        Text("\(formatDistance(calculateDistance(rssi: device.rssi)))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Signal strength
                    HStack(spacing: 4) {
                        Image(systemName: "wifi")
                            .font(.system(size: 10))
                            .foregroundColor(signalColor(for: device.rssi))
                        
                        Text("\(device.rssi ?? 0) dBm")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    
                    // Battery if available
                    if let batteryLevel = device.batteryLevel {
                        HStack(spacing: 4) {
                            Image(systemName: batteryIcon(for: batteryLevel))
                                .font(.system(size: 10))
                                .foregroundColor(batteryColor(for: batteryLevel))
                            
                            Text("\(batteryLevel)%")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.gray)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDevice = device
        }
    }
    
    // Helper functions for UI
    private func deviceTypeIcon(for device: Device) -> String {
        switch device.type {
        case .headphones: return "headphones"
        case .speaker: return "hifispeaker"
        case .watch: return "applewatch"
        case .phone: return "iphone"
        case .tablet: return "ipad"
        case .laptop: return "laptopcomputer"
        case .computer: return "desktopcomputer"
        case .keyboard: return "keyboard"
        case .mouse: return "mouse"
        case .unknown: return "dot.radiowaves.left.and.right"
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
}

#Preview {
    RadarView(viewModel: RadarViewModel())
        .environmentObject(DeviceManager())
} 