//
//  ProductDetailView.swift
//  IKEA_NC1
//
//  Created by Federica Mosca on 22/11/23.
//

import SwiftUI

struct ProductDetailView: View {
    
    @Environment(\.dismiss) private var isPresented
    @State private var arIsPresented = false
    
    let screenSize = UIScreen.main.bounds

    var card: Card
    
    func formatCurrency(value: Double) -> String {
                let formatter = NumberFormatter()
                formatter.numberStyle = .currency
                formatter.locale = Locale.current

                return formatter.string(from: NSNumber(value: value)) ?? ""
            }
    
    var body: some View {
        ScrollView{
            VStack{
                Spacer()


                
                HStack{

                    
                    
                    Button(action: {
                        arIsPresented = true
//                        backgroundLogic.arViewPresented = arIsPresented
                    }, label: {
                        HStack{
                            Image(systemName: "cube.transparent")
                            Text("AR View")
                                .bold()
                                .font(LimiTypography.footnote)
            
                        }
                    }).tint(.themeBlack)
                    .padding()
                    .background(Capsule().fill(Color.themeWhite))
                    .overlay(
                        Capsule()
                            .stroke(Color.themeBlack, lineWidth: 1)
                            .frame(height: 40)
                    )
                    .fullScreenCover(isPresented: $arIsPresented, content: {
                        ProductARView(card: card)
                    })
                    .statusBarHidden()



                    
                } //: HSTACK
                .padding(.horizontal,15)
                

                
                
                
            } //: VSTACK
            .padding(.horizontal)
            
        }
    }
}

#Preview {
    ProductDetailView(card: Card(imageName: ["chairFront","chairSide","chairBack"], title: "Placeholder", price: 49, description: "Placeholder", objectName: "ceilingmultiplependants", size: "22 x 22 x 22", color: "red"))
        .environment(BackgroundLogic())
}
