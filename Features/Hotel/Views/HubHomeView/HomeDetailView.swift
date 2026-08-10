//
//  HomeDetailView.swift
//  LimiExhibition
//
//  Created by Mac Mini on 04/03/2025.
//

import SwiftUI


struct HomeDetailView: View {
    let hub: Hub
    @Environment(\.dismiss) private var dismiss

    @State private var selectedController: ControllerType = .pwm2LED
    @State private var isTransitioning = false

    var body: some View {
        ZStack {
            Color.appCanvasPrimary
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
                            LimiBackButton { dismiss() }
                                .padding(.leading, 16)
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
                .background(Color.appCanvasPrimary)
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
                .font(LimiTypography.callout)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .foregroundColor(isSelected ? .appCanvasPrimary : .appTextPrimary)
                .background(
                    Capsule(style: .continuous)
                        .fill(
                            isSelected
                            ? AnyShapeStyle(LimiGradients.cta)
                            : AnyShapeStyle(Color.appGlassFillMedium)
                        )
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.appGlassFillStrong.opacity(isSelected ? 0 : 1), lineWidth: 0.5)
                )
        }
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.4 : 1.0)
        .tapScale()
    }
}
#Preview {
    let dummyHub = Hub(name: "Dummy Hub")
    HomeDetailView(hub: dummyHub)
}
