//
//  ContentView.swift
//  ForReal Demo
//
//  Created by Vatsal Patel  on 8/17/24.
//

import SwiftUI

struct RoomPlanContentView: View {
    @Environment(RoomCaptureController.self) private var captureController
    @State private var navigateToHome = false
    @State private var files: [String] = []
    @State private var analyzingFile: String? = nil
    @State private var showAnalysisAlert = false


    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvasPrimary.ignoresSafeArea()

                List {
                    ForEach(files, id: \.self) { file in
                        NavigationLink(destination: FileDetailView(fileName: file)) {
                            Text(file)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {

                                analyzingFile = file
                                analyzeFileDimensions(file)
                                showAnalysisAlert = true
                            } label: {
                                Label("Analyze", systemImage: "ruler")
                            }
                            .tint(.green)
                            Button(role: .destructive) {
                                if RoominatorFileManager.shared.deleteFile(named: file) {
                                    deleteModelFromBackend(filename: file) { success in
                                        DispatchQueue.main.async {
                                            if success {
                                                print("🗑️ Swipe deleted '\(file)' from backend too")
                                            }
                                        }
                                    }
                                    files.removeAll { $0 == file }
                                }
                            } label: {
                                Label("Delete", systemImage: "bin")
                            }
                            .tint(.red)

                        }
                    }
                    .onDelete(perform: deleteFiles)
                }

                if files.isEmpty {
                    VStack {
                        Image("ARLogo")
                            .resizable()
                            .frame(width: 120, height: 24)
                        Image("roomImage3")
                            .resizable()
                            .frame(width: 250, height: 250)
                        Text("You have no existing scans")
                        Text("Make a new scan!")
                    }
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 120)
                }

            }
            .navigationTitle("Room Scans")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    LimiBackButton { navigateToHome = true }
                }

//                ToolbarItem(placement: .navigationBarTrailing) {
//                    NavigationLink(destination: FileListView()) {
//                        Image(systemName: "plus")
//                            .foregroundStyle(Color.appTextPrimary)
//                            .padding(.horizontal, 8)
//                            .padding(.vertical, 3)
//                            .background(Color.emerald)
//                            .cornerRadius(8)
//                    }
//                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ScanNewRoomView()) {
                        Image(systemName: "plus")
                            .foregroundStyle(Color.appTextPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.appCanvasPrimary)
                            .cornerRadius(8)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton().foregroundStyle(Color.appCanvasPrimary)
                }
            }
            .onAppear {
                if AuthManager.shared.isAuthenticated {
                    syncLocalStorageWithBackend {
                        refreshFileList()
                    }
                } else {
                    refreshFileList()
                }
            }

//            .onAppear {
//                if AuthManager.shared.isAuthenticated {
//                    ScanSyncManager.downloadScansFromBackend()
//
//                    // Wait 2 seconds before refreshing local list
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
//                        refreshFileList()
//                    }
//                } else {
//                    refreshFileList()
//                }
//            }
//            .onAppear {
//                //testDownloadUSDZModel()
//                refreshFileList()
//            }

            .alert("Room Analysis", isPresented: $showAnalysisAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Dimensions for \(analyzingFile ?? "room") have been printed to the Xcode console.")
            }
            .navigationDestination(isPresented: $navigateToHome) {
                HomeView()
            }
        }
    }
//    func testDownloadUSDZModel() {
//        let fileName = "shahrukh-apple-model.usdz"
//        let urlString = "https://api.limitless-lighting.co.uk/client/3d-models/download/6849120769d171a46073cbe5"
//
//        guard let url = URL(string: urlString) else {
//            print("❌ Invalid URL")
//            return
//        }
//
//        URLSession.shared.dataTask(with: url) { data, _, error in
//            if let error = error {
//                print("❌ Error downloading file:", error)
//                return
//            }
//
//            guard let data = data, data.count > 0 else {
//                print("❌ No data or zero bytes received from:", url)
//                return
//            }
//
//            let success = RoominatorFileManager.shared.saveUSDZFile(data, withName: fileName)
//            if success {
//                print("✅ File '\(fileName)' downloaded and saved locally.")
//            } else {
//                print("❌ Failed to save the file.")
//            }
//        }.resume()
//    }

    private func deleteFiles(at offsets: IndexSet) {
        for index in offsets {
            let fileName = files[index]

            // Local deletion
            if RoominatorFileManager.shared.deleteFile(named: fileName) {
                // Backend deletion
                deleteModelFromBackend(filename: fileName) { success in
                    DispatchQueue.main.async {
                        if success {
                            print("🗑️ Deleted '\(fileName)' from both local and backend.")
                        } else {
                            print("⚠️ Deleted '\(fileName)' locally, but backend deletion failed.")
                        }
                    }
                }

                files.remove(at: index)
            }
        }
    }
    
    func deleteModelFromBackend(filename: String, completion: @escaping (Bool) -> Void) {
        fetchBackendUSDZList { models in
            guard let model = models.first(where: { ($0["filename"] as? String) == filename }),
                  let id = model["_id"] as? String,
                  let token = AuthManager.shared.getToken() else {
                print("❌ Model not found on backend or missing token")
                completion(false)
                return
            }

            let urlString = APIConstants.uploadRoom3DModel + "\(id)"
            guard let url = URL(string: urlString) else {
                print("❌ Invalid delete URL")
                completion(false)
                return
            }

            var request = URLRequest(url: url)
            request.httpMethod = "DELETE"
            request.setValue(token, forHTTPHeaderField: "Authorization")

            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    print("❌ Backend delete error: \(error)")
                    completion(false)
                } else {
                    print("✅ Deleted from backend: \(filename)")
                    completion(true)
                }
            }.resume()
        }
    }

    
    
    func fetchBackendUSDZList(completion: @escaping ([[String: Any]]) -> Void) {
        guard let token = AuthManager.shared.getToken() else {
            print("❌ No token found")
            completion([])
            return
        }

        var request = URLRequest(url: URL(string: APIConstants.uploadRoom3DModel)!)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data else {
                print("❌ Fetch error: \(error?.localizedDescription ?? "Unknown error")")
                completion([])
                return
            }

            // 🔍 Debug raw response (optional)
            if let raw = String(data: data, encoding: .utf8) {
                print("📦 Raw response: \(raw)")
            }

            do {
                // Parse the top-level dictionary
                if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let dataArray = json["data"] as? [[String: Any]] {
                    print("✅ Parsed models: \(dataArray.count) items")
                    completion(dataArray)
                } else {
                    print("❌ Invalid JSON format: expected [String: Any] with key 'data' as [[String: Any]]")
                    completion([])
                }
            } catch {
                print("❌ JSON parsing error: \(error)")
                completion([])
            }
        }.resume()
    }

    func getMissingFilenames(from backendData: [[String: Any]]) -> [String] {
        let localFiles = RoominatorFileManager.shared.listFiles()
        let backendFilenames = backendData.compactMap { $0["filename"] as? String }
        let missing = backendFilenames.filter { !localFiles.contains($0) }
        return missing
    }

    func downloadUSDZFile(id: String, filename: String, completion: @escaping (Bool) -> Void) {
        // ✅ Check if file already exists
        if RoominatorFileManager.shared.usdzFileExists(named: filename) {
            print("✅ File '\(filename)' already exists locally. Skipping download.")
            completion(true)
            return
        }

        guard let token = AuthManager.shared.getToken() else {
            print("❌ No token")
            completion(false)
            return
        }

        let urlString = APIConstants.uploadRoom3DModel + "\(id)"
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "Authorization")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("❌ Download error: \(error?.localizedDescription ?? "Unknown error")")
                completion(false)
                return
            }

            let success = RoominatorFileManager.shared.saveUSDZFile(data, withName: filename)
            if success {
                print("✅ File '\(filename)' downloaded and saved.")
            } else {
                print("❌ Failed to save file '\(filename)'")
            }
            completion(success)
        }.resume()
    }
    
 



    func syncLocalStorageWithBackend(completion: @escaping () -> Void) {
        fetchBackendUSDZList { models in
            let group = DispatchGroup()
            for model in models {
                if let id = model["_id"] as? String,
                   let filename = model["filename"] as? String {
                    group.enter()
                    downloadUSDZFile(id: id, filename: filename) { success in
                        if success {
                            print("✅ Downloaded: \(filename)")
                        }
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                print("🟢 Sync finished")
                completion()
            }
        }
    }

    
    private func refreshFileList() {
        files = RoominatorFileManager.shared.listFiles()
    }


    
    private func analyzeFileDimensions(_ fileName: String) {
        // Call the analyze method from RoomCaptureController
        captureController.analyzeUSDZFile(fileName)
    }
}

#Preview {
    RoomPlanContentView()
        .environment(RoomCaptureController())
}
