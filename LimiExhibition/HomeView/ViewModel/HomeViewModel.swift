//
//  HomeViewModel.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//
import SwiftUI

// ViewModel to handle business logic and state management
class HomeViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var isSidebarOpen = false
    @Published var searchText = ""
    @Published var linkedDevices: [DeviceHome] = []
    @Published var isNavigatingToAddDevice = false
    @Published var showARScan = false
    @Published var showCustomer = false
    @Published var showGrouping = false
    @Published var showWebView = false
    @Published var selectedTab = 0
    
    // Animation states
    @Published var isLoaded = false
    @Published var searchFieldFocused = false
    @Published var headerOffset: CGFloat = -100
    @Published var shimmerAnimation = false  // For shimmer effect
    
    // MARK: - Dependencies
    private let deviceService: DeviceServiceProtocol
    
    // MARK: - Initialization
    init(deviceService: DeviceServiceProtocol = DeviceService()) {
        self.deviceService = deviceService
    }
    
    // MARK: - Methods
    func fetchLinkedDevices() {
        deviceService.fetchLinkedDevices { [weak self] result in
            switch result {
            case .success(let devices):
                DispatchQueue.main.async {
                    self?.linkedDevices = devices
                }
            case .failure(let error):
                print("Error fetching linked devices: \(error)")
            }
        }
    }
    
    func setupInitialState() {
        // Trigger animations when view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation {
                self.headerOffset = 0
                self.isLoaded = true
            }
        }
        self.shimmerAnimation = true
        fetchLinkedDevices()
    }
}
