import SwiftUI

struct AddDeviceView: View {
    @State private var currentScreen: Screen = .addDevices
    @State private var scanProgress: Double = 0
    @State private var isAnimating = false
    @State private var showBackButton = true // Track back button visibility

    enum Screen {
        case addDevices
        case scanning
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.charlestonGreen.edgesIgnoringSafeArea(.all)

                if currentScreen == .addDevices {
                    AddDevicesView(onOptionSelected: { option in
                        if option == .nearby {
                            withAnimation {
                                currentScreen = .scanning
                                startScanningAnimation()
                            }
                        }
                    })
                    .padding(.top, 10)
                } else {
                    ScanningView(
                        progress: scanProgress,
                        isAnimating: isAnimating,
                        onBack: {
                            withAnimation {
                                currentScreen = .addDevices
                            }
                        }
                    )
                }
                
                VStack {
                    HStack {
                        if showBackButton {
                            Button(action: {
                                // Navigate to HomeView
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                                    window.rootViewController = UIHostingController(rootView: HomeView())
                                    window.makeKeyAndVisible()
                                }
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.alabaster)
                                    .font(.title)
                            }
                            .padding(.leading, 30)
                            .padding(.top, -6)
                        }
                        
                        Spacer()
                    }
                    
                    Spacer()
                }
            }
            .preferredColorScheme(.dark)
            .onAppear {
                // Set the visibility of the back button based on the current screen
                updateBackButtonVisibility()
            }
            .onChange(of: currentScreen) { _, _ in
                // Update back button visibility whenever the screen changes
                updateBackButtonVisibility()
            }
        }
    }
    
    private func startScanningAnimation() {
        isAnimating = true
        scanProgress = 0
        
        withAnimation(.easeInOut(duration: 5)) {
            scanProgress = 0.18
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            withAnimation(.easeInOut(duration: 15)) {
                scanProgress = 1.0
            }
        }
    }
    
    private func updateBackButtonVisibility() {
        withAnimation {
            showBackButton = (currentScreen == .addDevices)
        }
    }
}

struct AddDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        AddDeviceView()
    }
}
