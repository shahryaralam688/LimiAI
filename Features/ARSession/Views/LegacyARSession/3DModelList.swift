//
//  PortalCongigurator.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 11/12/2025.
//

import SwiftUI
import Network

struct ARModelList: View {
    @StateObject private var viewModel = ARSessionViewModel()
    @StateObject private var stateManager = ARModelStateManager.shared
    @StateObject private var networkMonitor = NetworkMonitor()

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isUsingPresets && viewModel.showPresetBanner {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("Using built-in presets")
                        .font(.caption)
                        .foregroundColor(.orange)
                    Spacer()
                    Button(action: { viewModel.showPresetBanner = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.15))
            }

            if !viewModel.displayItems.isEmpty {
                VStack {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 0) {
                                ForEach(viewModel.displayItems) { item in
                                    Button(action: {
                                        viewModel.selectItem(item)
                                    }) {
                                        VStack(spacing: 6) {
                                            HStack(spacing: 4) {
                                                Text(item.name)
                                                    .font(.subheadline)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                                if item.isPreset {
                                                    Image(systemName: "cube.fill")
                                                        .font(.caption2)
                                                        .foregroundColor(.orange)
                                                }
                                            }
                                            .padding(.horizontal, 2)
                                            .foregroundColor(.themeWhite)
                                            .padding(4)
                                            .background(stateManager.selectedModelId == item.id ? Color.gray.opacity(0.5) : Color.clear)
                                            .cornerRadius(6)

                                            Image("1.0")
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 45, height: 45)
                                                .padding(4)
                                                .background(
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(stateManager.selectedModelId == item.id ? Color.themeWhite : Color.clear, lineWidth: 2)
                                                )
                                        }
                                        .frame(width: UIScreen.main.bounds.width / 3.5)
                                        .padding(.vertical, 8)
                                        .id(item.id)
                                    }
                                    .buttonStyle(.plain)

                                    if item.id != viewModel.displayItems.last?.id {
                                        Divider()
                                            .frame(height: 60)
                                            .background(Color.gray.opacity(0.3))
                                    }
                                }
                            }
                        }
                        .onChange(of: stateManager.selectedModelId) { newId in
                            if let id = newId {
                                withAnimation {
                                    proxy.scrollTo(id, anchor: .center)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(
                    RoundedRectangle(cornerRadius: 0)
                        .fill(Color.themeBlack.opacity(0.9))
                )
                .padding(.horizontal, 0)

            } else if viewModel.isLoading {
                HStack {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .themeWhite))
                    Text("Loading models...")
                        .foregroundColor(.themeWhite)
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .background(Color.themeBlack.opacity(0.9))
            }
        }
        .padding(.horizontal, 0)
        .onAppear {
            viewModel.onAppear()
        }
        .alert("Offline Mode", isPresented: $viewModel.showOfflineAlert) {
            Button("Use Presets", role: .cancel) {
                viewModel.confirmOfflinePresets()
            }
            Button("Retry", role: .none) {
                viewModel.fetchLightConfigs()
            }
        } message: {
            Text("Unable to load your devices. You can use built-in preset models or retry when connected.")
        }
        .onChange(of: networkMonitor.isConnected) { isConnected in
            if isConnected {
                viewModel.onNetworkReconnected()
            }
        }
    }
}

#Preview {
    ARModelList()
}
