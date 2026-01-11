// AddDevicesView.swift
import SwiftUI

enum ConnectionOption {
    case qrCode
    case nearby
    case manual
}

struct AddDevicesView: View {
    var onOptionSelected: (ConnectionOption) -> Void
    @State private var animateOptions = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Animated title
            VStack(alignment: .leading, spacing: 8) {
                Text("Add your devices")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.charlestonGreen)
                    .padding(.top, 20)
                
                Text("Select the method of adding the device")
                    .font(.system(size: 16))
                    .foregroundColor(.charlestonGreen.opacity(0.8))
                    .padding(.bottom, 16)
            }
            .opacity(animateOptions ? 1 : 0)
            .offset(y: animateOptions ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateOptions)
            
            // Connection options with staggered animation
            VStack(spacing: 16) {
//                ConnectionOptionCard(
//                    icon: "qrcode",
//                    title: "Scan QR Code",
//                    description: "Quickly connect by scanning the device QR code",
//                    delay: 0.2,
//                    isAnimated: animateOptions,
//                    action: { onOptionSelected(.qrCode) }
//                )
                
                ConnectionOptionCard(
                    icon: "wave.3.right",
                    title: "Nearby Devices",
                    description: "Find and connect to devices in your vicinity",
                    delay: 0.3,
                    isAnimated: animateOptions,
                    action: { onOptionSelected(.nearby) }
                )
                
//                ConnectionOptionCard(
//                    icon: "keyboard",
//                    title: "Manual Setup",
//                    description: "Enter device details manually for connection",
//                    delay: 0.4,
//                    isAnimated: animateOptions,
//                    action: { onOptionSelected(.manual) }
//                )
            }
            
            Spacer()
            
            // Bottom tip with animation
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.emerald)
                
                Text("Tip: Nearby scanning works best when you're within 10 feet of the device")
                    .font(.caption)
                    .foregroundColor(.charlestonGreen.opacity(0.7))
            }
            .padding()
            .background(Color.charlestonGreen.opacity(0.2))
            .cornerRadius(12)
            .opacity(animateOptions ? 1 : 0)
            .offset(y: animateOptions ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateOptions)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .background(
            RoundedRectangle(cornerRadius: 30)
                .fill(Color.alabaster.opacity(0.9))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .onAppear {
            // Trigger animations when view appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    animateOptions = true
                }
            }
        }
    }
}

struct ConnectionOptionCard: View {
    let icon: String
    let title: String
    let description: String
    let delay: Double
    let isAnimated: Bool
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            // Reset press state after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    isPressed = false
                }
                
                // Trigger the action after the animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    action()
                }
            }
        }) {
            HStack(spacing: 16) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.charlestonGreen.opacity(0.7), Color.charlestonGreen.opacity(0.4)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.charlestonGreen)
                    
                    Text(description)
                        .font(.system(size: 14))
                        .foregroundColor(.charlestonGreen.opacity(0.7))
                        .lineLimit(2)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.charlestonGreen)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: Color.charlestonGreen.opacity(0.05), radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .opacity(isAnimated ? 1 : 0)
        .offset(x: isAnimated ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay), value: isAnimated)
    }
}
