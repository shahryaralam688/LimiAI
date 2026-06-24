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
            print("❌ No valid token found.")
            return
        }

        LimiHTTPClient.perform(request) { data, response, error in
            if let error = error {
                print("❌ Error fetching scans:", error)
                return
            }

            guard let data = data else {
                print("❌ No data received")
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
            } catch {
                print("❌ Error parsing JSON:", error)
            }
        }
    }

    static func downloadAndSaveScanFile(fileName: String, downloadURL: String) {
        guard let url = URL(string: downloadURL) else {
            print("❌ Invalid download URL:", downloadURL)
            return
        }

        LimiHTTPClient.perform(URLRequest(url: url)) { data, _, error in
            if let error = error {
                print("❌ Error downloading file:", error)
                return
            }

            guard let data = data else {
                print("❌ No data received from:", url)
                return
            }

            let success = RoominatorFileManager.shared.saveUSDZFile(data, withName: fileName)
            if success {
                print("✅ File \(fileName) downloaded and saved locally.")
            }
        }
    }
}
