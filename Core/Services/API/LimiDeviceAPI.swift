//
//  LimiDeviceAPI.swift
//  Limi
//
//  Shared Limi backend device endpoints.
//

import Foundation

enum LimiDeviceAPI {

    static func postProcessDeviceData(
        deviceInfo: String,
        completion: ((Data?, HTTPURLResponse?, Error?) -> Void)? = nil
    ) {
        LimiHTTPClient.postJSON(
            urlString: APIConstants.processDeviceData,
            body: ["deviceInfo": deviceInfo]
        ) { data, response, error in
            if let error {
                print("Error sending device info: \(error.localizedDescription)")
            } else if let data, let responseString = String(data: data, encoding: .utf8) {
                print("Response from server: \(responseString)")
            }
            completion?(data, response, error)
        }
    }

    static func postDeviceUser(
        body: [String: Any],
        logPrefix: String = "DeviceUser",
        completion: ((Data?, HTTPURLResponse?, Error?) -> Void)? = nil
    ) {
        LimiHTTPClient.postJSON(
            urlString: APIConstants.deviceUser,
            body: body
        ) { data, response, error in
            if let error {
                print("❌ [\(logPrefix)] Network error: \(error.localizedDescription)")
            }
            if let http = response {
                print("📬 [\(logPrefix)] HTTP Status: \(http.statusCode)")
            }
            if let data, let bodyText = String(data: data, encoding: .utf8), !bodyText.isEmpty {
                print("📩 [\(logPrefix)] Response Body: \(bodyText)")
            }
            completion?(data, response, error)
        }
    }
}
