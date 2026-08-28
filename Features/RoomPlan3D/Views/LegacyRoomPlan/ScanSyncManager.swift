//
//  ScanSyncManager.swift
//  Limi
//
//  Created by Mac Mini on 03/06/2025.
//


import Foundation

class ScanSyncManager {
    static func downloadScansFromBackend() {
        guard let url = URL(string: APIConstants.roomPlanScans) else { return }
        guard let request = LimiHTTPClient.buildRequest(
            url: url,
            method: "GET"
        ) else {
            return
        }

        LimiHTTPClient.perform(request) { data, response, error in
            if let error = error {
                return
            }

            guard let data = data else {
                return
            }

            do {
                if let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for file in json {
                        if let fileName = file["fileName"] as? String,
                           let downloadURL = file["downloadURL"] as? String {
                            downloadAndSaveScanFile(fileName: fileName, downloadURL: downloadURL)
                        }
                    }
                }
            } catch { /* ignored */ }
        }
    }

    static func downloadAndSaveScanFile(fileName: String, downloadURL: String) {
        guard let url = URL(string: downloadURL) else {
            return
        }

        LimiHTTPClient.perform(URLRequest(url: url)) { data, _, error in
            if let error = error {
                return
            }

            guard let data = data else {
                return
            }

            let success = RoominatorFileManager.shared.saveUSDZFile(data, withName: fileName)
            if success {
            }
        }
    }
}
