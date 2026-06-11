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

    private let endpoint = URL(string: APIConstants.deviceUser)!

    func allocateDevice(deviceId: String) {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📡 [DeviceAllocation] STARTED for deviceId: \(deviceId)")

        guard let token = AuthManager.shared.getToken(), !token.isEmpty else {
            print("❌ [DeviceAllocation] No valid token. Cannot allocate device.")
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")

        print("🔗 [DeviceAllocation] URL: \(endpoint.absoluteString)")
        print("📋 [DeviceAllocation] Method: POST")
        print("🔑 [DeviceAllocation] Authorization: \(String(token.prefix(30)))...")
        print("📎 [DeviceAllocation] Content-Type: application/json")

        let body: [String: String] = [
            "deviceId": deviceId
        ]

        do {
            let encoded = try JSONEncoder().encode(body)
            request.httpBody = encoded
            if let json = String(data: encoded, encoding: .utf8) {
                print("📤 [DeviceAllocation] Body: \(json)")
            }
            print("📏 [DeviceAllocation] Body size: \(encoded.count) bytes")
        } catch {
            print("❌ [DeviceAllocation] Failed to encode body: \(error)")
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("❌ [DeviceAllocation] Network error: \(error.localizedDescription)")
                return
            }

            if let http = response as? HTTPURLResponse {
                print("📬 [DeviceAllocation] HTTP Status: \(http.statusCode)")
                print("📬 [DeviceAllocation] Response Headers: \(http.allHeaderFields)")
            }

            guard let data = data else {
                print("❌ [DeviceAllocation] Empty response data")
                return
            }

            if let raw = String(data: data, encoding: .utf8) {
                print("📩 [DeviceAllocation] Response Body: \(raw)")
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
        }.resume()
    }
}
