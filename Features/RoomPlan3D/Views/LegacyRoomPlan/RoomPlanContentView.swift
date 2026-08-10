//
//  RoomPlanContentView.swift
//  ForReal Demo
//
//  Created by Vatsal Patel  on 8/17/24.
//

import SwiftUI

struct RoomPlanContentView: View {
    @Environment(RoomCaptureController.self) private var captureController
    @Environment(\.dismiss) private var dismiss
    @State private var listViewModel = RoomPlanListViewModel()
    @State private var showUnsupportedScanAlert = false

    private var canStartNewScan: Bool { RoomPlanCapability.isCaptureSupported }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvasPrimary.ignoresSafeArea()

                List {
                    ForEach(listViewModel.files, id: \.self) { file in
                        NavigationLink(destination: FileDetailView(fileName: file)) {
                            Text(file)
                        }
                        .swipeActions(edge: .trailing) {
                            Button {
                                listViewModel.beginAnalysis(for: file) { fileName in
                                    captureController.viewModel.analyzeUSDZFile(fileName)
                                }
                            } label: {
                                Label("Analyze", systemImage: "ruler")
                            }
                            .tint(.green)
                            Button(role: .destructive) {
                                listViewModel.deleteFileByName(file)
                            } label: {
                                Label("Delete", systemImage: "bin")
                            }
                            .tint(.red)
                        }
                    }
                    .onDelete(perform: listViewModel.deleteFiles)
                }

                if listViewModel.files.isEmpty {
                    emptyState
                }
            }
            .navigationTitle("Room Scans")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LimiCloseToolbarButton { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    if canStartNewScan {
                        NavigationLink(destination: ScanNewRoomView()) {
                            plusGlyph
                        }
                        .accessibilityLabel("Start new room scan")
                    } else {
                        Button {
                            showUnsupportedScanAlert = true
                        } label: {
                            plusGlyph
                        }
                        .accessibilityLabel("Start new room scan unavailable")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton().foregroundStyle(Color.appCanvasPrimary)
                }
            }
            .onAppear {
                listViewModel.onAppear(isAuthenticated: AuthManager.shared.isAuthenticated)
            }
            .alert("Room Analysis", isPresented: $listViewModel.showAnalysisAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Dimensions for \(listViewModel.analyzingFile ?? "room") have been printed to the Xcode console.")
            }
            .alert(
                RoomPlanCapability.unsupportedTitle,
                isPresented: $showUnsupportedScanAlert
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(RoomPlanCapability.unsupportedMessage)
            }
            .trackScreen(
                "RoomPlanContentView",
                metadata: [
                    "surface": "room_scan_list",
                    "roomplan_capture_supported": canStartNewScan ? "true" : "false"
                ]
            )
        }
    }

    private var plusGlyph: some View {
        Image(systemName: "plus")
            .foregroundStyle(Color.appTextPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.appCanvasPrimary)
            .cornerRadius(8)
            .opacity(canStartNewScan ? 1 : 0.45)
    }

    @ViewBuilder
    private var emptyState: some View {
        if canStartNewScan {
            VStack {
                Image("ARLogo")
                    .resizable()
                    .frame(width: 120, height: 24)
                Image("roomImage3")
                    .resizable()
                    .frame(width: 250, height: 250)
                Text("You have no existing scans")
                Text("Tap + to scan a room with your Pro camera")
            }
            .font(LimiTypography.headline)
            .foregroundColor(.appTextSecondary)
            .multilineTextAlignment(.center)
            .padding(.bottom, LimiSpacing.floatingOrbClearance + 20)
        } else {
            RoomPlanUnsupportedView()
                .padding(.bottom, LimiSpacing.floatingOrbClearance)
        }
    }
}

#Preview {
    RoomPlanContentView()
        .environment(RoomCaptureController())
}
