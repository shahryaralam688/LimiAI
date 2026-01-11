//
//  SearchBarView.swift
//  Limi
//
//  Created by Mac Mini on 18/04/2025.
//


import SwiftUI
// MARK: - Search Bar Component
struct SearchBarView: View {
    @Binding var searchText: String
    @Binding var searchFieldFocused: Bool
    @Binding var showARScan: Bool
    @Binding var isLoaded: Bool
    
    var body: some View {
        HStack {
            TextField("Search for a device...", text: $searchText)
                .padding(.horizontal, 15)
                .frame(height: 45)
                .background(
                    RoundedRectangle(cornerRadius: 15)
                        .fill(Color.white.opacity(0.9))
                        .shadow(color: Color.black.opacity(0.1), radius: searchFieldFocused ? 8 : 3, x: 0, y: 2)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15)
                                .stroke(Color.eton.opacity(searchFieldFocused ? 0.5 : 0), lineWidth: 2)
                        )
                )
                .onTapGesture {
                    withAnimation {
                        searchFieldFocused = true
                    }
                }
                .onSubmit {
                    searchFieldFocused = false
                }
            Spacer()
            
            // MARK: - Scan Button
            Button(action: {
                print("AR Scan button tapped")
                showARScan = true  // Trigger AR experience
                withAnimation(.spring()) {
                    let impactMed = UIImpactFeedbackGenerator(style: .medium)
                    impactMed.impactOccurred()
                }
            }) {
                ZStack {
                    // Animated ring
                    Circle()
                        .stroke(Color.eton.opacity(0.3), lineWidth: 2)
                        .frame(width: 50, height: 50)
                        .scaleEffect(isLoaded ? 1.2 : 0.8)
                        .opacity(isLoaded ? 0.0 : 0.8)
                        .animation(
                            Animation.easeInOut(duration: 1.5)
                                .repeatForever(autoreverses: false),
                            value: isLoaded
                        )
                    
                    // Button background
                    Circle()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.charlestonGreen, Color.charlestonGreen.opacity(0.8)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 45, height: 45)
                        .shadow(color: Color.black.opacity(0.15), radius: 5, x: 0, y: 3)
                    
                    // Icon
                    Image(systemName: "cube.transparent")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundColor(.alabaster)
                        .frame(width: 22, height: 22)
                        .scaleEffect(isLoaded ? 1.0 : 0.95)
                }
            }
        }
        .padding(.horizontal, 5)
        .padding(.top, 0)
        .offset(y: -5)
    }
}
