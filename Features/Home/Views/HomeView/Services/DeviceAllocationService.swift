import Foundation

struct DeviceAllocationData: Decodable {
    let allocationId: String?
    let message: String?
    let success: Bool?
}

struct DeviceAllocationResponse: Decodable {
    let success: Bool
    let message: String
    let data: DeviceAllocationData?
}

final class DeviceAllocationService {
    static let shared = DeviceAllocationService()

    private init() {}

    func allocateDevice(deviceId: String) {

        LimiDeviceAPI.postDeviceUser(
            body: ["deviceId": deviceId],
            logPrefix: "DeviceAllocation"
        ) { data, _, error in
            if let error {
                return
            }

            guard let data else {
                return
            }

            do {
                let decoded = try JSONDecoder().decode(DeviceAllocationResponse.self, from: data)
                if let dataObject = decoded.data {
                }
            } catch { /* ignored */ }
        }
    }
}
