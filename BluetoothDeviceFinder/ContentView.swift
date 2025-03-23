//
//  ContentView.swift
//  BluetoothDeviceFinder
//
//  Created by Kerem Türközü on 22.03.2025.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var deviceManager = DeviceManager()
    
    var body: some View {
        TabView {
            DeviceListView()
                .tabItem {
                    Label("Devices", systemImage: "antenna.radiowaves.left.and.right")
                }
            
            DeviceMapView()
                .tabItem {
                    Label("Map", systemImage: "map")
                }
        }
        .environmentObject(deviceManager)
    }
}

#Preview {
    ContentView()
}
