//
//  SkeuoBox.swift
//  Limi
//
//  Created by Mac Mini on 02/07/2025.
//


import SwiftUI

struct SkeuoBox: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Enter Your Email")
                .font(.title2.bold())
                .foregroundColor(.charlestonGreen)
                .shadow(color: .white.opacity(0.5), radius: 1, x: -1, y: -1)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 1, y: 1)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial) // 🔥 Native SwiftUI blur
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding()
    }
}

#Preview {
    SkeuoBox()
}
