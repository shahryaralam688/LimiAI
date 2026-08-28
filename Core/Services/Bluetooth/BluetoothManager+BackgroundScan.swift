//
//  BluetoothManager+BackgroundScan.swift
//  Limi
//

import CoreBluetooth
import ObjectiveC
import UIKit

// MARK: - Background scanning + interest device popup

extension BluetoothManager {
    // LIMI devices that trigger Apple-style proximity pairing cards.
    private var interestDeviceNames: Set<String> {
        [
            "1 CH-HUB", "4 CH-HUB", "8 CH-HUB", "16 CH-HUB",
            "Mini Controller", "LIMI Device", "limi1ch-EC3564"
        ]
    }

    /// Periodic scan bursts for hub popups when no screen owns an active scan session.
    /// Only runs while the app is in the foreground — unrestricted BLE scan in background
    /// is a common cause of iOS terminating the process.
    /// - Parameter interestPopups: When false (LIMI AI Device), never show Hub Found overlays.
    func enableBackgroundScan(interestPopups: Bool = true) {
        interestDevicePopupsEnabled = interestPopups
        backgroundDiscoveryDesired = true
        scheduleBackgroundScanTick()
    }

    /// Device companion app: BLE control without random hub discovery popups / scan bursts.
    func configureForDeviceCompanionApp() {
        interestDevicePopupsEnabled = false
        backgroundDiscoveryDesired = false
        pauseBackgroundDiscovery()
    }

    func pauseBackgroundDiscovery() {
        backgroundScanTimer?.invalidate()
        backgroundScanTimer = nil
        stopCentralScanIfIdle()
    }

    func resumeBackgroundDiscoveryIfNeeded() {
        guard backgroundDiscoveryDesired else { return }
        guard backgroundScanTimer == nil else { return }
        scheduleBackgroundScanTick()
    }

    // MARK: - Internal helpers

    private func scheduleBackgroundScanTick() {
        backgroundScanTimer?.invalidate()
        startBackgroundScanCycle()
        backgroundScanTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            self?.startBackgroundScanCycle()
        }
        if let backgroundScanTimer {
            RunLoop.main.add(backgroundScanTimer, forMode: .common)
        }
    }

    private func startBackgroundScanCycle() {
        // Never run discovery bursts when suspended / inactive — OS kill risk.
        guard UIApplication.shared.applicationState == .active else { return }
        guard activeScanSessions == 0 else {
            return
        }
        guard let cm = centralManager else { return }
        if cm.state == .poweredOn {
            cm.stopScan()
            discoveredDevices.removeAll()
            // No AllowDuplicates — cuts CPU / memory pressure that triggers jetsam.
            cm.scanForPeripherals(withServices: nil, options: nil)
            DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in
                guard let self, self.activeScanSessions == 0 else { return }
                guard UIApplication.shared.applicationState == .active else {
                    self.centralManager?.stopScan()
                    return
                }
                self.centralManager?.stopScan()
            }
        } else {
            deferredScan = true
        }
    }

    func notifyInterestDeviceIfNeeded(name: String, id: String) {
        guard interestDevicePopupsEnabled else { return }
        guard activeScanSessions == 0 else { return }
        handleInterestDeviceDiscovered(name: name, id: id)
    }

    fileprivate func handleInterestDeviceDiscovered(name: String, id: String) {
        guard interestDeviceNames.contains(name) else { return }
        GlobalDevicePopup.shared.showDeviceFound(
            deviceName: name,
            deviceId: id
        ) { [weak self] in
            GlobalDevicePopup.shared.showConnecting(deviceName: name, deviceId: id)
            self?.selectAndConnect(name: name, uuidString: id)
        }
    }
}

// MARK: - Stored properties for timer (same file to access privates)

extension BluetoothManager {
    private struct AssociatedKeys {
        static var backgroundScanTimerKey: UInt8 = 0
        static var interestPopupsKey: UInt8 = 1
        static var backgroundDiscoveryDesiredKey: UInt8 = 2
    }

    private var backgroundScanTimer: Timer? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.backgroundScanTimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &AssociatedKeys.backgroundScanTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var interestDevicePopupsEnabled: Bool {
        get {
            (objc_getAssociatedObject(self, &AssociatedKeys.interestPopupsKey) as? Bool) ?? true
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.interestPopupsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    private var backgroundDiscoveryDesired: Bool {
        get {
            (objc_getAssociatedObject(self, &AssociatedKeys.backgroundDiscoveryDesiredKey) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.backgroundDiscoveryDesiredKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}
