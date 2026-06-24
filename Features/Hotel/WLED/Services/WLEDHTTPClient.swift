import Foundation

/// Local HTTP client for WLED devices on the LAN (Phase H).
enum WLEDHTTPClient {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 3
        configuration.timeoutIntervalForResource = 8
        return URLSession(configuration: configuration)
    }()

    static func get(
        urlString: String,
        timeout: TimeInterval = 3
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: urlString) else {
            throw WLEDHTTPError.invalidURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WLEDHTTPError.invalidResponse
        }
        return (data, http)
    }

    static func postJSON(
        urlString: String,
        body: [String: Any],
        timeout: TimeInterval = 5
    ) async throws -> (Data, HTTPURLResponse) {
        guard let url = URL(string: urlString) else {
            throw WLEDHTTPError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw WLEDHTTPError.invalidResponse
        }
        return (data, http)
    }

    static func probeJSONObject(
        urlString: String,
        timeout: TimeInterval = 2,
        completion: @escaping (Result<[String: Any], Error>) -> Void
    ) {
        guard let url = URL(string: urlString) else {
            completion(.failure(WLEDHTTPError.invalidURL))
            return
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        session.dataTask(with: request) { data, response, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(.failure(WLEDHTTPError.invalidResponse))
                return
            }
            completion(.success(json))
        }.resume()
    }
}

enum WLEDHTTPError: LocalizedError {
    case invalidURL
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid WLED URL"
        case .invalidResponse: return "Invalid WLED response"
        }
    }
}

/// SSDP / mDNS discovery surface (testable via protocol).
protocol WLEDDiscovering: ObservableObject {
    var discoveredDevices: [WLEDDevice] { get }
    var isScanning: Bool { get }
    var errorMessage: String? { get }
    func startDiscovery()
    func stopDiscovery()
}

extension SSDPDiscoveryManager: WLEDDiscovering {}
