//
//  ScanQRCode.swift
//  Limi
//
//  Created by Mac Mini on 12/03/2025.
//

import SwiftUI
struct ScanQRCodeView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.charlestonGreen,
                    Color.alabaster
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)
        }
    }
}
    
  
