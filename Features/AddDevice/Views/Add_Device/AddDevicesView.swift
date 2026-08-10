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
            VStack(alignment: .leading, spacing: 8) {
                Text("Add your devices")
                    .font(LimiTypography.largeTitle)
                    .foregroundColor(.appTextPrimary)
                    .padding(.top, 20)

                Text("Select the method of adding the device")
                    .font(LimiTypography.body)
                    .foregroundColor(.appTextSecondary)
                    .padding(.bottom, 16)
            }
            .opacity(animateOptions ? 1 : 0)
            .offset(y: animateOptions ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.1), value: animateOptions)

            VStack(spacing: 16) {
                ConnectionOptionCard(
                    icon: "wave.3.right",
                    title: "Nearby Devices",
                    description: "Find and connect to devices in your vicinity",
                    delay: 0.3,
                    isAnimated: animateOptions,
                    action: { onOptionSelected(.nearby) }
                )
            }

            Spacer()

            HStack(spacing: 10) {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.brandHighlight)
                Text("Tip: Nearby scanning works best when you're within 10 feet of the device")
                    .font(LimiTypography.caption)
                    .foregroundColor(.appTextSecondary)
            }
            .padding(LimiSpacing.innerPadding)
            .glassCard(cornerRadius: LimiRadius.small)
            .opacity(animateOptions ? 1 : 0)
            .offset(y: animateOptions ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.5), value: animateOptions)
        }
        .padding(.horizontal, LimiSpacing.screenHorizontal)
        .padding(.bottom, 24)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation { animateOptions = true }
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
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation { isPressed = false }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { action() }
        }) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(LimiGradients.ctaVertical)
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .font(LimiTypography.title3)
                        .foregroundColor(.appTextInverse)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(LimiTypography.button)
                        .foregroundColor(.appTextPrimary)
                    Text(description)
                        .font(LimiTypography.subheadline)
                        .foregroundColor(.appTextSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(LimiTypography.callout)
                    .foregroundColor(.brandHighlight)
            }
            .padding(LimiSpacing.innerPadding)
            .glassCard(cornerRadius: LimiRadius.medium)
            .scaleEffect(isPressed ? 0.97 : 1.0)
        }
        .buttonStyle(.plain)
        .opacity(isAnimated ? 1 : 0)
        .offset(x: isAnimated ? 0 : -20)
        .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(delay), value: isAnimated)
    }
}
