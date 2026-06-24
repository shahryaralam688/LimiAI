//
//  BluetoothManager+BackgroundScan.swift
//  Limi
//

import CoreBluetooth
import ObjectiveC

// MARK: - Background scanning + interest device popup

extension BluetoothManager {
    // Only these get a popup
    private var interestDeviceNames: Set<String> { ["1 CH-HUB", "4 CH-HUB"] }

    // Call once at app launch (e.g., in App.init or SceneDelegate) to keep scanning in the background.
    // Does not require any view to be on-screen.
    func enableBackgroundScan() {
        // Start scanning and route discoveries through our handler
        startScanning { [weak self] devices in
            guard let self = self else { return }
            for item in devices {
                self.handleInterestDeviceDiscovered(name: item.name, id: item.id)
            }
        }
        // Also maintain periodic scan cycles to keep discovery fresh.
        scheduleBackgroundScanTick()
    }

    // MARK: - Internal helpers

    private func scheduleBackgroundScanTick() {
        backgroundScanTimer?.invalidate()
        // Kick off immediately
        startBackgroundScanCycle()
        // Repeat periodically
        backgroundScanTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.startBackgroundScanCycle()
        }
        if let backgroundScanTimer {
            RunLoop.main.add(backgroundScanTimer, forMode: .common)
        }
    }

    private func startBackgroundScanCycle() {
        guard let cm = centralManager else { return }
        if cm.state == .poweredOn {
            // Short scan burst with duplicates allowed to catch brief advertisements
            cm.stopScan()
            discoveredDevices.removeAll()
            cm.scanForPeripherals(withServices: nil,
                                  options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
                self?.centralManager?.stopScan()
            }
        } else {
            // When BT powers on, startScanning() will pick it up due to internal deferral
            deferredScan = true
        }
    }

    fileprivate func handleInterestDeviceDiscovered(name: String, id: String) {
        guard interestDeviceNames.contains(name) else { return }
        GlobalDevicePopup.shared.showDeviceFound(
            title: "Hub Found",
            deviceName: name,
            deviceId: id
        ) { [weak self] in
            self?.selectAndConnect(name: name, uuidString: id)
        }
    }
}

// MARK: - Stored properties for timer (same file to access privates)

extension BluetoothManager {
    private struct AssociatedKeys {
        static var backgroundScanTimerKey: UInt8 = 0
    }

    private var backgroundScanTimer: Timer? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.backgroundScanTimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &AssociatedKeys.backgroundScanTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }
}
