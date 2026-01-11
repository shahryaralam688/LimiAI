//import SwiftUI
//
//struct RoomViewerWrapper: View {
//    @Environment(\.presentationMode) var presentationMode
//    let fileURL: URL
//    @State private var resetCamera = false
//    @State private var showTextureMenu = false
//    @State private var showModelMenu = false
//    @State private var selectedMaterialType = ""
//    @State private var selectedMaterialName = ""
//    
//    // Available textures
//    let wallTextures = ["brick_texture", "ground_texture", "wood_texture", "stone_texture"]
//    let floorTextures = ["floor_texture", "tile_texture", "carpet_texture", "marble_texture"]
//    
//    // Available 3D models
//    let availableModels = [
//        ModelItem(name: "FloorLamp", fileName: "FloorLamp.usdz", displayName: "Floor Lamp", icon: "lamp.floor"),
//        ModelItem(name: "Chair", fileName: "chair_swan.usdz", displayName: "Swan Chair", icon: "chair"),
//        ModelItem(name: "Toaster", fileName: "toaster.usdz", displayName: "Toaster", icon: "microwave")
//    ]
// 
//    var body: some View {
//        ZStack(alignment: .topTrailing) {
//            RoomViewerView(fileURL: fileURL, resetCameraTrigger: $resetCamera)
//            
//            VStack {
//                HStack {
//                    // Model Selection Button
//                    Button(action: {
//                        showModelMenu = true
//                    }) {
//                        Image(systemName: "plus.circle.fill")
//                            .font(.system(size: 25))
//                            .foregroundColor(.blue)
//                            .background(Color.white.opacity(0.8))
//                            .clipShape(Circle())
//                    }
//                    
//                    Button(action: {
//                        resetCamera = true
//                    }) {
//                        Text("Reset")
//                            .padding(10)
//                            .background(Color.black.opacity(0.6))
//                            .foregroundColor(.white)
//                            .cornerRadius(8)
//                    }
//                    
//                    Spacer()
//                    
//                    // Save Model Button - Send notification to coordinator
//                    Button("Save Model") {
//                        NotificationCenter.default.post(
//                            name: NSNotification.Name("SaveEditedModel"),
//                            object: nil,
//                            userInfo: ["originalURL": fileURL]
//                        )
//                    }
//                    .padding(10)
//                    .background(Color.green.opacity(0.6))
//                    .foregroundColor(.white)
//                    .cornerRadius(8)
//                    
//                    Button(action: {
//                        presentationMode.wrappedValue.dismiss()
//                    }) {
//                        Image(systemName: "xmark.circle.fill")
//                            .font(.system(size: 30))
//                            .foregroundColor(.white)
//                    }
//                }
//                .padding()
//                
//                Spacer()
//            }
//            
//            // Model Selection Menu
//            if showModelMenu {
//                VStack {
//                    Spacer()
//                    
//                    VStack(spacing: 20) {
//                        Text("Select 3D Model")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        
//                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
//                            ForEach(availableModels, id: \.name) { model in
//                                Button(action: {
//                                    addModel(model)
//                                }) {
//                                    VStack {
//                                        Image(systemName: model.icon)
//                                            .font(.system(size: 40))
//                                            .foregroundColor(.blue)
//                                            .frame(width: 80, height: 60)
//                                            .background(Color.white.opacity(0.2))
//                                            .cornerRadius(10)
//                                        
//                                        Text(model.displayName)
//                                            .font(.caption)
//                                            .foregroundColor(.white)
//                                    }
//                                }
//                            }
//                        }
//                        
//                        Button("Cancel") {
//                            showModelMenu = false
//                        }
//                        .foregroundColor(.red)
//                        .padding()
//                    }
//                    .padding()
//                    .background(Color.black.opacity(0.8))
//                    .cornerRadius(15)
//                    .padding()
//                }
//                .transition(.move(edge: .bottom))
//                .animation(.easeInOut, value: showModelMenu)
//            }
//            
//            // Texture Selection Menu
//            if showTextureMenu {
//                VStack {
//                    Spacer()
//                    
//                    VStack(spacing: 20) {
//                        Text("Select \(selectedMaterialType) Texture")
//                            .font(.headline)
//                            .foregroundColor(.white)
//                        
//                        Text("Material: \(selectedMaterialName)")
//                            .font(.subheadline)
//                            .foregroundColor(.gray)
//                        
//                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 15) {
//                            ForEach(getAvailableTextures(), id: \.self) { textureName in
//                                Button(action: {
//                                    applyTexture(textureName)
//                                }) {
//                                    VStack {
//                                        if let image = UIImage(named: textureName) {
//                                            Image(uiImage: image)
//                                                .resizable()
//                                                .aspectRatio(contentMode: .fill)
//                                                .frame(width: 80, height: 80)
//                                                .clipped()
//                                                .cornerRadius(10)
//                                        } else {
//                                            Rectangle()
//                                                .fill(Color.gray)
//                                                .frame(width: 80, height: 80)
//                                                .cornerRadius(10)
//                                        }
//                                        
//                                        Text(getTextureDisplayName(textureName))
//                                            .font(.caption)
//                                            .foregroundColor(.white)
//                                    }
//                                }
//                            }
//                        }
//                        
//                        Button("Cancel") {
//                            showTextureMenu = false
//                        }
//                        .foregroundColor(.red)
//                        .padding()
//                    }
//                    .padding()
//                    .background(Color.black.opacity(0.8))
//                    .cornerRadius(15)
//                    .padding()
//                }
//                .transition(.move(edge: .bottom))
//                .animation(.easeInOut, value: showTextureMenu)
//            }
//        }
//        .background(Color.black.edgesIgnoringSafeArea(.all))
//        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowTextureMenu"))) { notification in
//            if let userInfo = notification.userInfo,
//               let materialType = userInfo["materialType"] as? String,
//               let materialName = userInfo["materialName"] as? String {
//                selectedMaterialType = materialType
//                selectedMaterialName = materialName
//                showTextureMenu = true
//            }
//        }
//    }
//    
//    func getAvailableTextures() -> [String] {
//        return selectedMaterialType == "Wall" ? wallTextures : floorTextures
//    }
//    
//    func getTextureDisplayName(_ textureName: String) -> String {
//        return textureName.replacingOccurrences(of: "_texture", with: "").capitalized
//    }
//    
//    func applyTexture(_ textureName: String) {
//        // Send notification to apply texture
//        NotificationCenter.default.post(
//            name: NSNotification.Name("ApplySelectedTexture"),
//            object: nil,
//            userInfo: ["textureName": textureName]
//        )
//        showTextureMenu = false
//    }
//    
//    func addModel(_ model: ModelItem) {
//        // Send notification to add 3D model
//        NotificationCenter.default.post(
//            name: NSNotification.Name("AddModel"),
//            object: nil,
//            userInfo: ["modelItem": model]
//        )
//        showModelMenu = false
//    }
//}
//
//// Model data structure
//struct ModelItem {
//    let name: String
//    let fileName: String
//    let displayName: String
//    let icon: String
//}
