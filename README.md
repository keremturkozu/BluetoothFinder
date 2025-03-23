# Bluetooth Device Finder

A SwiftUI app to find and track Bluetooth devices using CoreBluetooth and CoreLocation.

## Features

- Scan for nearby Bluetooth devices
- View device signal strength and battery level
- Track last known location of devices
- View devices on a map
- Navigate to a device's last known location

## Project Structure

The project follows MVVM architecture with Core and Features structure:

### Core

- **Bluetooth**: Manages Bluetooth scanning and device connections
- **Location**: Handles location tracking and permissions
- **Notification**: Manages user notifications (planned feature)

### Features

- **DeviceList**: UI for displaying and interacting with a list of devices
- **DeviceDetail**: UI for viewing detailed information about a device
- **DeviceMap**: UI for viewing devices on a map

### Common

- **Models**: Contains data models like Device
- **Extensions**: Utility extensions
- **Utils**: Helper functions and utilities

## Requirements

- iOS 15.0+
- Xcode 13.0+
- Swift 5.5+

## Getting Started

1. Clone the repository
2. Open BluetoothDeviceFinder.xcodeproj in Xcode
3. Build and run the app on a physical device (Bluetooth functionality requires a real device)

## Permissions

The app requires the following permissions:

- Bluetooth: To scan for and connect to devices
- Location: To track where devices were last seen

## Future Features

- Radar view for finding devices
- Push notifications when devices go out of range
- Custom device names and icons
- Background scanning for devices
- Low battery alerts 