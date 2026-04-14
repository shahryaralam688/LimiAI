//
//  RoomScanViews.swift
//  ForReal Demo
//
//  Created by Vatsal Patel  on 8/17/24.
//

import Foundation
import SwiftUI
import RoomPlan

struct CameraCaptureView: UIViewRepresentable {
    @Environment(RoomCaptureController.self) private var captureController

    func makeUIView(context: Context) -> some UIView {
        captureController.roomCaptureView
    }
  
    func updateUIView(_ uiView: UIViewType, context: Context) {}
}

struct RoomScanningView: View {
    @Environment(RoomCaptureController.self) private var captureController
    @Environment(\.dismiss) var dismiss
    @State private var showNameInputSheet = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            CameraCaptureView()
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            captureController.stopSession()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            captureController.stopSession()
                        }
                        .opacity(captureController.isScanComplete ? 0 : 1)
                    }
                }
                .onAppear() {
                    captureController.showSaveButton = false
                    captureController.isScanComplete = false
                    captureController.startSession()
                }
            
            if captureController.showSaveButton {
                Button(action: {
                    showNameInputSheet = true
                }, label: {
                    Text("Save Scan").font(.title2)
                })
                .buttonStyle(.borderedProminent)
                .cornerRadius(40)
                .padding()
            }
        }
        .sheet(isPresented: $showNameInputSheet) {
            SaveScanView(captureController: captureController, dismiss: dismiss)
        }
    }
}

struct SaveScanView: View {
    @ObservedObject var captureController: RoomCaptureController
    var dismiss: DismissAction
    @Environment(\.dismiss) private var dismissSheet
    
    var body: some View {
        NavigationView {
            Form {
                TextField("Enter file name", text: $captureController.fileName)
            }
            .navigationTitle("Name Your Scan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        captureController.saveScan()
                        dismissSheet()
                        dismiss()
                        let fileNameWithExtension = captureController.fileName.hasSuffix(".usdz") ? captureController.fileName : "\(captureController.fileName).usdz"
                        if let fileURL = RoominatorFileManager.shared.getUSDZFileURL(for: fileNameWithExtension) {
                            captureController.uploadScanModel(fileURL: fileURL, metadata: ["name": captureController.fileName])
                        }
                    }
                }
            }
        }
    }
}

struct ScanNewRoomView: View {
    @Environment(RoomCaptureController.self) private var captureController

    var body: some View {
        NavigationStack {
            VStack {
                Image("roomIcon2")
                    .resizable()
                    .frame(width: 140, height: 140)
                Text("Get ready to scan your room").font(.title)
                Spacer().frame(height: 50)
                Text("Make sure to scan the room by pointing the camera at all surfaces.")
                    .multilineTextAlignment(.center)
                Spacer().frame(height: 50)
                NavigationLink(destination: RoomScanningView()) {
                    Text("Start Scan")
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .cornerRadius(24)
                .font(.title3)
            }
            .padding(.bottom, 100)
        }
    }
}
