//
//  FileManager.swift
//  ForReal Demo
//
//  Created by Vatsal Patel  on 8/17/24.
//

import Foundation

class RoominatorFileManager {
    static let shared = RoominatorFileManager()
    
    private init() {
        createForRealScansFolder()
    }
    
    private let folderName = "ForRealScans"// Flolder name in device
    
    private var ForRealScansFolderURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.appendingPathComponent(folderName)
    }
    
    func usdzFileExists(named filename: String) -> Bool {
            guard let folderURL = ForRealScansFolderURL else {
                return false
            }
            let fileURL = folderURL.appendingPathComponent(filename)
            return FileManager.default.fileExists(atPath: fileURL.path)
        }
    
    private func createForRealScansFolder() {
        guard var folderURL = ForRealScansFolderURL else {
            return
        }
        
        if !FileManager.default.fileExists(atPath: folderURL.path) {
            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
                var resourceValues = URLResourceValues()
                resourceValues.isExcludedFromBackup = true
                try folderURL.setResourceValues(resourceValues)
            } catch { /* ignored */ }
        } else {
        }
    }
    
    func saveUSDZFile(_ data: Data, withName fileName: String) -> Bool {
        guard let folderURL = ForRealScansFolderURL else {
            return false
        }
        
        let fileNameWithExtension = fileName.hasSuffix(".usdz") ? fileName : "\(fileName).usdz"
        let fileURL = folderURL.appendingPathComponent(fileNameWithExtension)
        
        do {
            try data.write(to: fileURL)
            return true
        } catch {
            return false
        }
    }
    
    func getUSDZFileURL(for fileName: String) -> URL? {
        guard let folderURL = ForRealScansFolderURL else { return nil }
        let fileNameWithExtension = fileName.hasSuffix(".usdz") ? fileName : "\(fileName).usdz"
        return folderURL.appendingPathComponent(fileNameWithExtension)
    }
    
    func listFiles() -> [String] {
        guard let folderURL = ForRealScansFolderURL else {
            
            return []
        }
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
            return fileURLs.map { $0.lastPathComponent }.filter { $0.hasSuffix(".usdz") }
        } catch {
            return []
        }
    }
    
    func deleteFile(named fileName: String) -> Bool {
        guard let fileURL = getUSDZFileURL(for: fileName) else {
            return false
        }
        
        do {
            try FileManager.default.removeItem(at: fileURL)
            return true
        } catch {
            return false
        }
    }
    
    func deleteAllScans() {
        let files = listFiles()
        for file in files {
            _ = deleteFile(named: file)
        }
    }
}
