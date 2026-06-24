import Foundation

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

    init(name: String,
         uuid: String,
         deviceType: DeviceType = .bluetooth,
         ipAddress: String? = nil,
         txtRecord: [String: String]? = nil,
         reachability: Reachability = .offline,
         lastSeen: Date? = nil) {
        self.name = name
        self.uuid = uuid
        self.id = uuid
        self.deviceType = deviceType
        self.ipAddress = ipAddress
        self.txtRecord = txtRecord
        self.reachability = reachability
        self.lastSeen = lastSeen
    }

    static func == (lhs: BLEDevice, rhs: BLEDevice) -> Bool {
        lhs.id == rhs.id &&
        lhs.name == rhs.name &&
        lhs.uuid == rhs.uuid &&
        lhs.deviceType == rhs.deviceType &&
        lhs.ipAddress == rhs.ipAddress &&
        lhs.txtRecord == rhs.txtRecord &&
        lhs.reachability == rhs.reachability &&
        lhs.lastSeen == rhs.lastSeen
    }

    func with(ip: String?, txt: [String:String]?, reach: Reachability, lastSeen: Date?) -> BLEDevice {
        BLEDevice(name: name, uuid: uuid, deviceType: deviceType, ipAddress: ip, txtRecord: txt, reachability: reach, lastSeen: lastSeen)
    }
}
