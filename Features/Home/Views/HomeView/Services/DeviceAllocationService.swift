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
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📡 [DeviceAllocation] STARTED for deviceId: \(deviceId)")

        LimiDeviceAPI.postDeviceUser(
            body: ["deviceId": deviceId],
            logPrefix: "DeviceAllocation"
        ) { data, _, error in
            if let error {
                print("❌ [DeviceAllocation] Network error: \(error.localizedDescription)")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                return
            }

            guard let data else {
                print("❌ [DeviceAllocation] Empty response data")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                return
            }

            do {
                let decoded = try JSONDecoder().decode(DeviceAllocationResponse.self, from: data)
                print("✅ [DeviceAllocation] success: \(decoded.success), message: \(decoded.message)")
                if let dataObject = decoded.data {
                    print("   ↳ allocationId: \(dataObject.allocationId ?? "nil")")
                    print("   ↳ inner message: \(dataObject.message ?? "nil")")
                    print("   ↳ inner success: \(dataObject.success.map { String($0) } ?? "nil")")
                }
            } catch {
                print("❌ [DeviceAllocation] Failed to decode JSON: \(error)")
            }
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }
}
