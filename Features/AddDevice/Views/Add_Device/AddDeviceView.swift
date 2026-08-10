import SwiftUI

struct AddDeviceView: View {
    @StateObject private var viewModel = AddDeviceViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appCanvasPrimary.ignoresSafeArea()

                if viewModel.currentScreen == .addDevices {
                    AddDevicesView(onOptionSelected: { option in
                        viewModel.handleOptionSelected(option)
                    })
                    .padding(.top, 10)
                } else {
                    BLEStarterView()
                }
                
                VStack {
                    HStack {
                        if viewModel.showBackButton {
                            LimiBackButton {
                                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                                   let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                                    window.rootViewController = UIHostingController(rootView: HomeView())
                                    window.makeKeyAndVisible()
                                }
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
            .trackScreen("AddDeviceView")
            .onAppear {
                viewModel.syncNavigationState()
            }
            .onChange(of: viewModel.currentScreen) { _, _ in
                viewModel.syncNavigationState()
            }
        }
    }
}

struct AddDeviceView_Previews: PreviewProvider {
    static var previews: some View {
        AddDeviceView()
    }
}
