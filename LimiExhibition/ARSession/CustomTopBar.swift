//
//  CustomTopBar.swift
//  IKEA_NC1
//
//  Created by Federica Mosca on 23/11/23.
//

import SwiftUI

struct CustomTopBar: View {
    
    //Checks if the Scene is in the background or active
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    
    // Simple local state from parent that decides AR vs Object
    @Binding var isARMode: Bool
    
    var body: some View {
        
        HStack{

            //Dismiss button
            Button{
                
                //Dismisses the AR View including the TopBar
                dismiss.callAsFunction()
                
            }label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.primary)
                    .font(.title2)
                    .frame(width: 40, height: 30)
                    .padding(7)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .tint(.primary)
            
            Spacer()
            
            //Custom Picker
            HStack(spacing: 1){
                
                //Left side of custom Picker (AR)
                Button{
                        //Selects AR as the active mode
                        isARMode = true
                }label: {
                    Text("AR")
                        .font(.footnote)
                        .frame(width: 70, height: 30)
                        .padding(7)
                        .background(isARMode ? .white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .foregroundStyle(isARMode ? .blue : .primary)
                .buttonStyle(FlatButtonStyle())
                .font(.callout)
                
                //Right side of custom Picker (Object)
                Button{
                        isARMode = false
                }label: {
                    Text("Object")
                        .font(.footnote)
                        .frame(width: 55, height: 30)
                        .padding(.horizontal, 10)
                        .padding(7)
                        .background(!isARMode ? Color.white : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    
                }
                .buttonStyle(FlatButtonStyle())
                .foregroundStyle(!isARMode ? Color.alabaster : .primary)
                .font(.callout)
                
            }
            .padding(2)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 15))
            
            Spacer()
            Spacer()
        }
        //If you close the app and repoen it, it switches the highlighted button to object
        .onChange(of: scenePhase) {
            if scenePhase == .background{
                isARMode = false
            }
        }
    }
}

#Preview {
    CustomTopBar(isARMode: .constant(true))
}

//Button Style that removes the click animation
struct FlatButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
    }
}
