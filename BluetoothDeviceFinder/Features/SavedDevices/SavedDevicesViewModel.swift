import Foundation
import Combine

class SavedDevicesViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var savedDevices: [Device] = []
    @Published var selectedDevice: Device?
    @Published var isLoading = true
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var deviceManager: DeviceManager?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    init() {}
    
    // MARK: - Dependency Injection
    func injectDeviceManager(_ deviceManager: DeviceManager) {
        self.deviceManager = deviceManager
        setupBindings()
    }
    
    // MARK: - Public Methods
    func selectDevice(_ device: Device) {
        selectedDevice = device
    }
    
    func removeDevice(_ device: Device) {
        guard let deviceManager = deviceManager else { return }
        deviceManager.removeDevice(device)
    }
    
    func updateDeviceLocation(_ device: Device) {
        guard let deviceManager = deviceManager else { return }
        deviceManager.updateDeviceLocation(device)
    }
    
    func toggleConnection(for device: Device) {
        guard let deviceManager = deviceManager else { return }
        
        if device.isConnected {
            deviceManager.disconnect(from: device)
        } else {
            deviceManager.connect(to: device)
        }
    }
    
    func deleteDevices(at offsets: IndexSet) {
        guard let deviceManager = deviceManager else { return }
        
        let devicesToDelete = offsets.map { savedDevices[$0] }
        for device in devicesToDelete {
            deviceManager.removeDevice(device)
        }
    }
    
    // MARK: - Private Methods
    private func setupBindings() {
        guard let deviceManager = deviceManager else { return }
        
        deviceManager.$devices
            .map { $0.filter { $0.isSaved } }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] devices in
                self?.savedDevices = devices
                self?.isLoading = false
            }
            .store(in: &cancellables)
        
        deviceManager.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .assign(to: \.errorMessage, on: self)
            .store(in: &cancellables)
    }
} 