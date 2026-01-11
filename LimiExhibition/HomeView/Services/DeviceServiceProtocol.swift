//
//  DeviceServiceProtocol.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//
import SwiftUI

// MARK: - Service Layer
// Protocol for device service to enable testing and dependency injection
protocol DeviceServiceProtocol {
    func fetchLinkedDevices(completion: @escaping (Result<[DeviceHome], Error>) -> Void)
}

// Concrete implementation of device service
class DeviceService: DeviceServiceProtocol {
    func fetchLinkedDevices(completion: @escaping (Result<[DeviceHome], Error>) -> Void) {
        guard let token = AuthManager.shared.getToken() else {
            completion(.failure(NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not logged in"])))
            return
        }
        
        guard let url = URL(string: APIConstants.getLinkDevices) else {
            completion(.failure(NSError(domain: "URLError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("\(token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "DataError", code: 404, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            do {
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("Raw API Response: \(jsonString)")
                }
                
                let decodedResponse = try JSONDecoder().decode(APIResponseHome.self, from: data)
                let devices = decodedResponse.devices.devices.map { device in
                    DeviceHome(
                        id: UUID().uuidString,
                        name: device.device_name,
                        deviceID: device.device_id,
                        isOn: false
                    )
                }
                completion(.success(devices))
            } catch {
                completion(.failure(error))
            }
        }.resume()
    }
}
