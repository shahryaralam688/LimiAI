//
//  ContentView.swift
//  ForReal Demo
//
//  Created by Vatsal Patel  on 8/17/24.
//

import SwiftUI

struct RoomPlanContentView: View {
    @Environment(RoomCaptureController.self) private var captureController
    @Environment(\.dismiss) private var dismiss
    @State private var listViewModel = RoomPlanListViewModel()

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
                    .padding(.bottom, LimiSpacing.floatingOrbClearance + 20)
                }
            }
            .navigationTitle("Room Scans")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    LimiCloseToolbarButton { dismiss() }
                }

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
                listViewModel.onAppear(isAuthenticated: AuthManager.shared.isAuthenticated)
            }
            .alert("Room Analysis", isPresented: $listViewModel.showAnalysisAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Dimensions for \(listViewModel.analyzingFile ?? "room") have been printed to the Xcode console.")
            }
            .trackScreen("RoomPlanContentView", metadata: ["surface": "room_scan_list"])
        }
    }
}

#Preview {
    RoomPlanContentView()
        .environment(RoomCaptureController())
}
