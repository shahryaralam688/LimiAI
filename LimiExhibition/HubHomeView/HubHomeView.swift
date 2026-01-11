//
//  HubHomeView.swift
//  LimiExhibition
//
//  Created by Mac Mini on 04/03/2025.
//
import SwiftUI

struct HubHomeView: View {
    @ObservedObject var bluetoothManager = BluetoothManager.shared  // ✅ Observe BluetoothManager

    var body: some View {
        ZStack {
            Color.eton
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HubHeaderView(title: "")
                
                ScrollView {
                    ForEach(bluetoothManager.storedHubs) { hub in  // ✅ Use storedHubs
                        NavigationLink(destination: HomeDetailView(hub: hub)) {
                            HubCardView(hub: hub, bluetoothManager: bluetoothManager)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding()
                }
            }
        }
        .navigationBarHidden(true)
    }
}

struct HubHeaderView: View {
    let title: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.charlestonGreen)
            
            Spacer()
            
            Button(action: {
                // Settings action
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundColor(.charlestonGreen)
            }
        }
        .padding()
        .background(Color.eton)
    }
}
    
struct HubContentView: View {
    var body: some View {
        NavigationStack {
            HubHomeView()
        }
    }
}

#Preview {

    HubContentView()
    
}
