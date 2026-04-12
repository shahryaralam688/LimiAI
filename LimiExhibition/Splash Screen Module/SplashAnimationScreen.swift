//
//  SplashAnimationScreen.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 16/12/2025.
//

import SwiftUI

struct SplashAnimationScreen: View {
    @State private var animateAll = false
    
    private let animationDuration: Double = 0.5
    
    var body: some View {
        ZStack {
            Color.themeBlack.ignoresSafeArea()
            
            // All vectors stacked on top of each other to form the full logo
            ZStack {
                animatedVector(name: "Vector1", index: 0)
                animatedVector(name: "Vector2", index: 1)
                animatedVector(name: "Vector3", index: 2)
                animatedVector(name: "Vector4", index: 3)
                animatedVector(name: "Vector5", index: 4)
                animatedVector(name: "Vector6", index: 5)
                animatedVector(name: "Vector7", index: 6)
                animatedVector(name: "Vector8", index: 7)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .onAppear {
            animateAll = false
            // Trigger the whole sequence once the view appears
            withAnimation(.easeOut(duration: animationDuration)) {
                animateAll = true
            }
        }
    }
    
    private func animatedVector(name: String, index: Int) -> some View {
        let baseDelay = 0.08
        
        return Image(name)
            .resizable()
            .scaledToFit()
            .opacity(animateAll ? 1 : 0)
            .offset(y: animateAll ? 0 : 20)
            .animation(
                .easeOut(duration: animationDuration)
                    .delay(baseDelay * Double(index)),
                value: animateAll
            )
    }
}

struct SplashAnimationScreen_Previews: PreviewProvider {
    static var previews: some View {
        SplashAnimationScreen()
    }
}
