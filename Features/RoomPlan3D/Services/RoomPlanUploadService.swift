import Foundation

/// RoomPlan 3D scan upload + backend sync (Phase K). All multipart via `LimiHTTPClient.perform`.
enum RoomPlanUploadService {

    static func uploadScan(
        fileURL: URL,
        metadata: [String: String],
        completion: @escaping (Bool, String?) -> Void
    ) {
        let boundary = UUID().uuidString
        guard let url = URL(string: APIConstants.uploadRoom3DModel),
              var request = LimiHTTPClient.buildRequest(
                url: url,
                method: "POST",
                contentType: nil
              ) else {
            completion(false, "Missing authorization token")
            return
        }

        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try buildMultipartBody(
                fileURL: fileURL,
                metadata: metadata,
                boundary: boundary
            )
        } catch {
            completion(false, error.localizedDescription)
            return
        }

        LimiHTTPClient.perform(request) { data, response, error in
            if let error {
                completion(false, error.localizedDescription)
                return
            }
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            let message = data.flatMap { String(data: $0, encoding: .utf8) }
            completion((200 ... 299).contains(status), message)
        }
    }

    static func fetchModels(completion: @escaping ([[String: Any]]) -> Void) {
        guard let url = URL(string: APIConstants.uploadRoom3DModel),
              let request = LimiHTTPClient.buildRequest(url: url, method: "GET") else {
            completion([])
            return
        }

        LimiHTTPClient.perform(request) { data, _, error in
            guard let data, error == nil else {
                completion([])
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]] {
                    completion(dataArray)
                } else {
                    completion([])
                }
            } catch {
                completion([])
            }
        }
    }

    static func deleteModel(filename: String, completion: @escaping (Bool) -> Void) {
        fetchModels { models in
            guard let model = models.first(where: { ($0["filename"] as? String) == filename }),
                  let id = model["_id"] as? String,
                  let url = URL(string: APIConstants.uploadRoom3DModel + id),
                  let request = LimiHTTPClient.buildRequest(url: url, method: "DELETE") else {
                completion(false)
                return
            }

            LimiHTTPClient.perform(request) { _, _, error in
                completion(error == nil)
            }
        }
    }

    static func downloadModel(id: String, filename: String, completion: @escaping (Bool) -> Void) {
        if RoominatorFileManager.shared.usdzFileExists(named: filename) {
            completion(true)
            return
        }

        guard let url = URL(string: APIConstants.uploadRoom3DModel + id),
              AuthManager.shared.getToken() != nil,
              let request = LimiHTTPClient.buildRequest(url: url, method: "GET") else {
            completion(false)
            return
        }

        LimiHTTPClient.perform(request) { data, _, error in
            guard let data, error == nil else {
                completion(false)
                return
            }
            completion(RoominatorFileManager.shared.saveUSDZFile(data, withName: filename))
        }
    }

    static func syncFromBackend(completion: @escaping () -> Void) {
        fetchModels { models in
            let group = DispatchGroup()
            for model in models {
                guard let id = model["_id"] as? String,
                      let filename = model["filename"] as? String else { continue }
                group.enter()
                downloadModel(id: id, filename: filename) { _ in
                    group.leave()
                }
            }
            group.notify(queue: .main, execute: completion)
        }
    }

    static func buildMultipartBody(
        fileURL: URL,
        metadata: [String: String],
        boundary: String
    ) throws -> Data {
        var body = Data()
        let fileData = try Data(contentsOf: fileURL)

        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: model/vnd.usdz+zip\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)

        for (key, value) in metadata {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"metadata[\(key)]\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(value)\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        return body
    }
}
