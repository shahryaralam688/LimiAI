import SwiftUI

struct FileListView: View {
    @State private var fileNames: [String] = []
    @State private var selectedFile: IdentifiableURL?
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            List(fileNames, id: \.self) { file in
                Button(action: {
                    if let url = RoominatorFileManager.shared.getUSDZFileURL(for: file) {
                        // Validate file before opening
                        if isValidUSDZFile(at: url) {
                            selectedFile = IdentifiableURL(url: url)
                        } else {
                            errorMessage = "The file '\(file)' appears to be corrupted or invalid."
                            showErrorAlert = true
                        }
                    } else {
                        errorMessage = "Could not locate the file '\(file)'."
                        showErrorAlert = true
                    }
                }) {
                    HStack {
                        Image(systemName: "cube.box")
                            .foregroundColor(.orbGlow4)
                        
                        VStack(alignment: .leading) {
                            Text(file)
                                .fontWeight(.medium)
                            
                            if let url = RoominatorFileManager.shared.getUSDZFileURL(for: file),
                               let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                               let modDate = attributes[.modificationDate] as? Date,
                               let fileSize = attributes[.size] as? UInt64 {
                                
                                Text("\(modDate, formatter: dateFormatter) • \(formatFileSize(fileSize))")
                                    .font(.caption)
                                    .foregroundColor(.appTextMuted)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Saved Room Scans")
//            .sheet(item: $selectedFile) { identifiableURL in
//               ?? RoomViewerWrapper(fileURL: identifiableURL.url)
//            }
            .alert(isPresented: $showErrorAlert) {
                Alert(
                    title: Text("Error Opening File"),
                    message: Text(errorMessage),
                    dismissButton: .default(Text("OK"))
                )
            }
            .refreshable {
                loadFiles()
            }
            .onAppear {
                loadFiles()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshFileList"))) { _ in
                loadFiles()
            }
        }
    }
    
    private func loadFiles() {
        fileNames = RoominatorFileManager.shared.listFiles()
    }
    
    // Helper function to check if a file is valid
    private func isValidUSDZFile(at url: URL) -> Bool {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("❌ File does not exist at path: \(url.path)")
            return false
        }
        
        // Check file size
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            if let fileSize = attributes[.size] as? UInt64 {
                let fileSizeMB = Double(fileSize) / 1024.0 / 1024.0
                print("📊 File size: \(String(format: "%.2f", fileSizeMB)) MB")
                
                // If file is too small, it's probably corrupted
                if fileSize < 1024 { // Less than 1KB
                    print("❌ File is too small, likely corrupted")
                    return false
                }
            }
        } catch {
            print("❌ Error checking file attributes: \(error)")
            return false
        }
        
        return true
    }
    
    // Format file size to human-readable format
    private func formatFileSize(_ size: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
    
    // Date formatter for file modification date
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

#Preview {
    FileListView()
}
