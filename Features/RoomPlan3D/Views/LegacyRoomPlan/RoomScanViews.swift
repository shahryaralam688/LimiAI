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
            if RoomPlanCapability.isCaptureSupported {
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
                            .opacity(captureController.viewModel.isScanComplete ? 0 : 1)
                        }
                    }
                    .onAppear {
                        captureController.viewModel.resetScanState()
                        captureController.startSession()
                    }

                if captureController.viewModel.showSaveButton {
                    Button(action: {
                        showNameInputSheet = true
                    }, label: {
                        Text("Save Scan").font(LimiTypography.title2)
                    })
                    .buttonStyle(.borderedProminent)
                    .cornerRadius(40)
                    .padding()
                }
            } else {
                // Final safety net if anything deep-links past the prep screen.
                RoomPlanUnsupportedView(showsCompatibleListHint: false) {
                    dismiss()
                }
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
        .sheet(isPresented: $showNameInputSheet) {
            SaveScanView(captureController: captureController, dismiss: dismiss)
        }
        .trackScreen(
            "RoomScanningView",
            metadata: [
                "surface": "room_scan_camera",
                "roomplan_capture_supported": RoomPlanCapability.isCaptureSupported ? "true" : "false"
            ]
        )
    }
}

struct SaveScanView: View {
    @Bindable var captureController: RoomCaptureController
    var dismiss: DismissAction
    @Environment(\.dismiss) private var dismissSheet
    @State private var fileName = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Enter file name", text: $fileName)
            }
            .navigationTitle("Name Your Scan")
            .onAppear {
                fileName = captureController.viewModel.fileName
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismissSheet() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        captureController.viewModel.fileName = fileName
                        dismissSheet()
                        captureController.viewModel.saveAndUploadScan {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct ScanNewRoomView: View {
    @Environment(RoomCaptureController.self) private var captureController
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if RoomPlanCapability.isCaptureSupported {
                    readyToScanContent
                } else {
                    RoomPlanUnsupportedView(showsCompatibleListHint: false) {
                        dismiss()
                    }
                }
            }
            .padding(.bottom, LimiSpacing.floatingOrbClearance)
            .navigationTitle("New Scan")
            .navigationBarTitleDisplayMode(.inline)
            .trackScreen(
                "ScanNewRoomView",
                metadata: [
                    "surface": "room_scan_prep",
                    "roomplan_capture_supported": RoomPlanCapability.isCaptureSupported ? "true" : "false"
                ]
            )
        }
    }

    private var readyToScanContent: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)

            Image("roomIcon2")
                .resizable()
                .frame(width: 140, height: 140)

            Text("Get ready to scan your room")
                .font(LimiTypography.title2)
                .foregroundStyle(Color.appTextPrimary)
                .multilineTextAlignment(.center)

            Text("Your Pro LiDAR camera maps the space in real time. Move slowly until every wall and major object is covered.")
                .font(LimiTypography.callout)
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(RoomPlanCapability.prepTips, id: \.self) { tip in
                    Label(tip, systemImage: "checkmark.circle.fill")
                        .font(LimiTypography.footnote)
                        .foregroundStyle(Color.appTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            Spacer().frame(height: 24)

            NavigationLink(destination: RoomScanningView()) {
                Text("Start Scan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.brandAction)
            .controlSize(.large)
            .padding(.horizontal, 24)

            Spacer(minLength: 8)
        }
        .padding(.horizontal, 24)
    }
}
