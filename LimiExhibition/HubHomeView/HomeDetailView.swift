//
//  HomeDetailView.swift
//  LimiExhibition
//
//  Created by Mac Mini on 04/03/2025.
//

import SwiftUI


struct HomeDetailView: View {
    let hub: Hub
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedController: ControllerType = .pwm2LED
    @State private var isTransitioning = false

    var body: some View {
        ZStack {
            Color.alabaster
                .ignoresSafeArea()
            
            if hub.name == "LIMI-CONTROLLER" {
                // Only show MiniControllerPreviewWrapper
                MiniControllerPreviewWrapper()
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .move(edge: .leading)),
                            removal: .opacity.combined(with: .move(edge: .trailing))
                        )
                    )
            } else {
                VStack {
                    VStack(spacing: 0) {
                        HStack {
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(.black)
                                    .font(.title2)
                                    .padding()
                            }
                            HubHeaderView(title: hub.name)
                        }
                        .padding(.horizontal)

                        // Controller selection
                        HStack(spacing: 20) {
                            ForEach(ControllerType.allCases) { controller in
                                ControllerButton(
                                    title: controller.rawValue,
                                    isSelected: selectedController == controller,
                                    isDisabled: selectedController != controller && !isTransitioning,
                                    action: {
                                        withAnimation {
                                            isTransitioning = true
                                            selectedController = controller
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                                isTransitioning = false
                                            }
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.vertical)

                        // Controller view
                        ZStack {
                            if selectedController == .pwm2LED {
                                PWM2LEDView(hub: hub)
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .leading)),
                                            removal: .opacity.combined(with: .move(edge: .trailing))
                                        )
                                    )
                            } else if selectedController == .dataRGB {
                                DataRGBView(hub: hub)
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .leading)),
                                            removal: .opacity.combined(with: .move(edge: .trailing))
                                        )
                                    )
                            } else {
                                MiniControllerView(hub: hub, brightness: .constant(0.5), warmCold: .constant(0.5))
                                    .transition(
                                        .asymmetric(
                                            insertion: .opacity.combined(with: .move(edge: .leading)),
                                            removal: .opacity.combined(with: .move(edge: .trailing))
                                        )
                                    )
                            }
                        }
                        .animation(.easeInOut(duration: 0.3), value: selectedController)

                        Spacer()
                    }
                }
                .background(Color.eton)
                .navigationBarHidden(true)
                .navigationTitle(hub.name)
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}


struct ControllerButton: View {
    let title: String
    let isSelected: Bool
    let isDisabled: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .foregroundColor(isSelected ? .white : .charlestonGreen)
                .background(isSelected ? Color.emerald : Color.white)
                .cornerRadius(20)
                .shadow(color: isSelected ? Color.emerald.opacity(0.3) : Color.gray.opacity(0.1), radius: 4, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(isSelected ? Color.emerald : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1.0)
    }
}
#Preview {
    let dummyHub = Hub(name: "Dummy Hub")
    HomeDetailView(hub: dummyHub)
}
