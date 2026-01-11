//
//  ScanSyncManager.swift
//  Limi
//
//  Created by Mac Mini on 03/06/2025.
//


import Foundation

class ScanSyncManager {
    static func downloadScansFromBackend() {
        guard let token = AuthManager.shared.getToken() else {
            print("❌ No valid token found.")
            return
        }

        guard let url = URL(string: "https://your-backend-url.com/api/scans") else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "GET"

        URLSession.shared.dataTask(with: request) { data, response, error in
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
        }.resume()
    }

    static func downloadAndSaveScanFile(fileName: String, downloadURL: String) {
        guard let url = URL(string: downloadURL) else {
            print("❌ Invalid download URL:", downloadURL)
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, error in
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
        }.resume()
    }
    

}
