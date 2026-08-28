import Foundation

/// Metadata when a scan row represents a virtual (master) device group.
struct VirtualMasterScanMetadata: Equatable {
    let virtualDeviceID: String
    let memberHardwareIds: [String]
    /// Live BLE/Wi‑Fi rows discovered for each member (used for provisioning).
    let memberDevices: [BLEDevice]

    static func == (lhs: VirtualMasterScanMetadata, rhs: VirtualMasterScanMetadata) -> Bool {
        lhs.virtualDeviceID == rhs.virtualDeviceID
            && lhs.memberHardwareIds == rhs.memberHardwareIds
    }
}

struct BLEDevice: Identifiable, Equatable {
    enum DeviceType: Equatable { case bluetooth, wifi }
    enum Reachability: String { case online, offline }

    let id: String
    let name: String
    let uuid: String                  // BLE: Peripheral UUID string; Wi-Fi: TXT deviceId or service.name
    let deviceType: DeviceType
    let ipAddress: String?
    let txtRecord: [String: String]?
    let reachability: Reachability
    let lastSeen: Date?
    /// When set, this row is a grouped virtual master (members are in `virtualMaster`).
    let virtualMaster: VirtualMasterScanMetadata?

    var isVirtualMaster: Bool { virtualMaster != nil }

    init(name: String,
         uuid: String,
         deviceType: DeviceType = .bluetooth,
         ipAddress: String? = nil,
         txtRecord: [String: String]? = nil,
         reachability: Reachability = .offline,
         lastSeen: Date? = nil,
         virtualMaster: VirtualMasterScanMetadata? = nil) {
        self.name = name
        self.uuid = uuid
        self.id = uuid
        self.deviceType = deviceType
        self.ipAddress = ipAddress
        self.txtRecord = txtRecord
        self.reachability = reachability
        self.lastSeen = lastSeen
        self.virtualMaster = virtualMaster
    }

    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.uuid == rhs.uuid &&
        lhs.deviceType == rhs.deviceType &&
        lhs.ipAddress == rhs.ipAddress &&
        lhs.txtRecord == rhs.txtRecord &&
        lhs.reachability == rhs.reachability &&
        lhs.lastSeen == rhs.lastSeen &&
        lhs.virtualMaster == rhs.virtualMaster
    }

    func with(
        name newName: String? = nil,
        ip: String?,
        txt: [String: String]?,
        reach: Reachability,
        lastSeen: Date?
    ) -> BLEDevice {
        BLEDevice(
            name: newName ?? name,
            uuid: uuid,
            deviceType: deviceType,
            ipAddress: ip,
            txtRecord: txt,
            reachability: reach,
            lastSeen: lastSeen,
            virtualMaster: virtualMaster
        )
    }

    /// Stable hardware MAC from Bonjour TXT, BLE name (`limi1ch-…`), or configured store.
    func resolvedHardwareId() -> String {
        if let txt = txtRecord?["deviceId"], !txt.isEmpty {
            return LimiDeviceNaming.normalizedHardwareId(txt)
        }
        let fromName = LimiDeviceNaming.normalizedHardwareId(name)
        if fromName.count == 12, fromName.allSatisfy(\.isHexDigit) {
            return fromName
        }
        if deviceType == .bluetooth {
            for record in ConfiguredBLEDeviceStore.shared.allRecords
            where record.blePeripheralUUID.caseInsensitiveCompare(uuid) == .orderedSame
                && ConfiguredBLEDeviceStore.isUsablePeripheralUUID(
                    record.blePeripheralUUID,
                    forHardwareId: record.hardwareId
                ) {
                return record.hardwareId
            }
        }
        let fromUUID = LimiDeviceNaming.normalizedHardwareId(uuid)
        // Do not treat a CBPeripheral UUID as a hardware MAC.
        if fromUUID.count == 12, fromUUID.allSatisfy(\.isHexDigit), !uuid.contains("-") {
            return ""
        }
        return fromUUID
    }
}
