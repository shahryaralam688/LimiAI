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
            } else if let data, let responseString = String(data: data, encoding: .utf8) {
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
            }
            if let http = response {
            }
            if let data, let bodyText = String(data: data, encoding: .utf8), !bodyText.isEmpty {
            }
            completion?(data, response, error)
        }
    }

    // MARK: - Virtual device (group MAC addresses under one cloud id)

    static func listVirtualDevices(
        scopeVirtualDeviceId: String? = nil,
        completion: ((Result<VirtualDeviceListEnvelope, Error>) -> Void)? = nil
    ) {
        let url = virtualDeviceListURL(scopeVirtualDeviceId: scopeVirtualDeviceId)
        LimiHTTPClient.get(urlString: url, auth: .requiredBearer) { data, response, error in
            if let error {
                completion?(.failure(error))
                return
            }
            guard let data else {
                completion?(.failure(LimiAPIError.emptyResponse))
                return
            }
            if let http = response, !(200 ... 299).contains(http.statusCode) {
                completion?(.failure(LimiAPIError.from(httpStatus: http.statusCode, data: data)))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(VirtualDeviceListEnvelope.self, from: data)
                completion?(.success(decoded))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    static func listVirtualDevices(scopeVirtualDeviceId: String? = nil) async throws -> VirtualDeviceListEnvelope {
        let url = virtualDeviceListURL(scopeVirtualDeviceId: scopeVirtualDeviceId)
        let data = try await LimiHTTPClient.get(urlString: url, auth: .requiredBearer)
        return try LimiHTTPClient.decode(VirtualDeviceListEnvelope.self, from: data)
    }

    /// Backward-compatible alias — returns the same list envelope from GET.
    static func getVirtualDevice(
        virtualDeviceId: String,
        completion: ((Result<VirtualDeviceListEnvelope, Error>) -> Void)? = nil
    ) {
        listVirtualDevices(scopeVirtualDeviceId: virtualDeviceId, completion: completion)
    }

    static func getVirtualDevice(virtualDeviceId: String) async throws -> VirtualDeviceListEnvelope {
        try await listVirtualDevices(scopeVirtualDeviceId: virtualDeviceId)
    }

    private static func virtualDeviceListURL(scopeVirtualDeviceId: String?) -> String {
        // Backend returns all user virtual devices; path id is optional scope.
        if let scopeVirtualDeviceId,
           !scopeVirtualDeviceId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return APIConstants.virtualDeviceDetail(scopeVirtualDeviceId)
        }
        return APIConstants.virtualDevice
    }

    /// POST `/client/devices/virtual-device`
    /// Headers: `Authorization: Bearer <jwt>`, `Content-Type: application/json`
    /// Body: `{ "virtual_device_id": "…", "mac_addresses": ["AA:BB:…", …] }`
    static func postVirtualDevice(
        virtualDeviceId: String,
        macAddresses: [String],
        completion: ((Result<VirtualDeviceAPIEnvelope, Error>) -> Void)? = nil
    ) {
        let body: [String: Any] = [
            "virtual_device_id": virtualDeviceId,
            "mac_addresses": macAddresses
        ]
        // Token is required — LimiHTTPClient attaches `Authorization: Bearer <jwt>`.
        LimiHTTPClient.postJSON(
            urlString: APIConstants.virtualDevice,
            body: body,
            auth: .requiredBearer
        ) { data, response, error in
            if let error {
                completion?(.failure(error))
                return
            }
            guard let data else {
                completion?(.failure(LimiAPIError.emptyResponse))
                return
            }
            if let http = response, !(200 ... 299).contains(http.statusCode) {
                completion?(.failure(LimiAPIError.from(httpStatus: http.statusCode, data: data)))
                return
            }
            do {
                let decoded = try JSONDecoder().decode(VirtualDeviceAPIEnvelope.self, from: data)
                guard decoded.success else {
                    completion?(
                        .failure(
                            LimiAPIError.backend(
                                message: decoded.message ?? "Virtual device save failed."
                            )
                        )
                    )
                    return
                }
                completion?(.success(decoded))
            } catch {
                completion?(.failure(error))
            }
        }
    }

    /// Async POST — same auth + payload as the completion-based API.
    static func postVirtualDevice(
        virtualDeviceId: String,
        macAddresses: [String]
    ) async throws -> VirtualDeviceAPIEnvelope {
        let body: [String: Any] = [
            "virtual_device_id": virtualDeviceId,
            "mac_addresses": macAddresses
        ]
        let data = try await LimiHTTPClient.postJSON(
            urlString: APIConstants.virtualDevice,
            body: body,
            auth: .requiredBearer
        )
        let decoded = try LimiHTTPClient.decode(VirtualDeviceAPIEnvelope.self, from: data)
        guard decoded.success else {
            throw LimiAPIError.backend(message: decoded.message ?? "Virtual device save failed.")
        }
        return decoded
    }
}

struct VirtualDeviceListEnvelope: Decodable {
    let success: Bool
    let message: String?
    let data: [VirtualDeviceRemotePayload]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)

        if let items = try? container.decode([VirtualDeviceRemotePayload].self, forKey: .data) {
            data = items
        } else if let single = try? container.decode(VirtualDeviceRemotePayload.self, forKey: .data) {
            data = [single]
        } else {
            data = []
        }
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case message
        case data
    }
}

struct VirtualDeviceAPIEnvelope: Decodable {
    let success: Bool
    let message: String?
    let data: VirtualDeviceRemotePayload?
}

struct VirtualDeviceRemotePayload: Decodable, Equatable {
    let virtual_device_id: String
    let mac_addresses: [String]

    init(virtual_device_id: String, mac_addresses: [String]) {
        self.virtual_device_id = virtual_device_id
        self.mac_addresses = mac_addresses
    }
}

/// Legacy alias — older call sites.
typealias VirtualDeviceAPIResponse = VirtualDeviceAPIEnvelope
