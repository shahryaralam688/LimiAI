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
                        .foregroundColor(.appWarning)
                    Text("Using built-in presets")
                        .font(LimiTypography.caption)
                        .foregroundColor(.appWarning)
                    Spacer()
                    Button(action: { viewModel.showPresetBanner = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.appTextMuted)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.appOrange.opacity(0.15))
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
                                                    .font(LimiTypography.subheadline)
                                                    .multilineTextAlignment(.center)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.8)
                                                if item.isPreset {
                                                    Image(systemName: "cube.fill")
                                                        .font(LimiTypography.caption2)
                                                        .foregroundColor(.appWarning)
                                                }
                                            }
                                            .padding(.horizontal, 2)
                                            .foregroundColor(.appTextPrimary)
                                            .padding(4)
                                            .background(stateManager.selectedModelId == item.id ? Color.appBorderPrimary.opacity(0.5) : Color.clear)
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
                                            .background(Color.appBorderPrimary.opacity(0.45))
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
                        .progressViewStyle(CircularProgressViewStyle(tint: .appTextPrimary))
                    Text("Loading models...")
                        .foregroundColor(.appTextPrimary)
                        .font(LimiTypography.subheadline)
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
