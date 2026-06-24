//
//  LimiConfiguratorAPI.swift
//  Limi
//
//  Shared 3D configurator / light-config backend calls.
//

import Foundation

enum LimiConfiguratorAPI {

    static func checkLightConfigs(
        completion: @escaping (Result<[Any], Error>) -> Void
    ) {
        LimiHTTPClient.postJSON(
            urlString: APIConstants.lightConfigsCheck,
            body: [:]
        ) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [Any] else {
                completion(.success([]))
                return
            }
            completion(.success(json))
        }
    }

    static func fetchLightConfig(
        spanID: String,
        completion: @escaping ([String: Any]?) -> Void
    ) {
        LimiHTTPClient.get(urlString: APIConstants.lightConfig(spanID)) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                completion(nil)
                return
            }
            completion(json)
        }
    }

    static func downloadUSDZ(
        downloadId: String,
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        LimiHTTPClient.download(
            urlString: APIConstants.webConfiguratorDownload(downloadId)
        ) { data, _, error in
            if let error {
                completion(.failure(error))
                return
            }
            guard let data else {
                completion(.failure(URLError(.zeroByteResource)))
                return
            }
            completion(.success(data))
        }
    }
}
