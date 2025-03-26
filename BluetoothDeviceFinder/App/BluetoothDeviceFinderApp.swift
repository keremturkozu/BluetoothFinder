//
//  BluetoothDeviceFinderApp.swift
//  BluetoothDeviceFinder
//
//  Created by Kerem Türközü on 22.03.2025.
//

import SwiftUI

@main
struct BluetoothDeviceFinderApp: App {
    @StateObject private var deviceManager = DeviceManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(deviceManager)
                .onAppear {
                    deviceManager.locationService.requestAuthorization()
                }
        }
    }
}
