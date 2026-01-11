import SwiftUI

struct GroupingView: View {
    @ObservedObject var bluetoothManager = BluetoothManager.shared
    @StateObject private var sharedDevice = SharedDevice.shared
    @Binding var showGrouping: Bool

    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(bluetoothManager.storedHubs.prefix(5)) { hub in
                        HStack {
                            Text(hub.name)
                            Spacer()
                            if let connectedDevice = sharedDevice.connectedDevice,
                               connectedDevice.id == hub.id.uuidString {
                                Text("Connected")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .onDelete(perform: deleteHub) // Add delete action
                }
                .listStyle(PlainListStyle())
                .onAppear {
                    bluetoothManager.startScanning { devices in
                        // Handle device updates if needed
                    }
                }
                
                Button(action: runSequence) {
                    Text("Run Sequence")
                        .font(.headline)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("Connected Hubs")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        showGrouping = false
                    }) {
                        Image(systemName: "xmark")
                            .font(.headline)
                            .foregroundColor(.primary)
                    }
                }
            }
            .onReceive(bluetoothManager.$storedHubs) { _ in
                // Handle updates to stored hubs if needed
            }
        }
    }
    
    func runSequence() {
        let hubs = bluetoothManager.storedHubs.prefix(5)
        for (index, hub) in hubs.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 6) {
                let byteArray: [UInt8] = [0x01, 0x32, 0x32, 0x32]
                sendMessage(hub: hub, message: byteArray)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    let byteArray: [UInt8] = [0x01, 0x00, 0x00, 0x00]
                    sendMessage(hub: hub, message: byteArray)
                }
            }
        }
    }
    
    private func sendMessage(hub: Hub, message: [UInt8]) {
        if let _ = bluetoothManager.connectedDevices[hub.id] {
            let data = Data(message)
            bluetoothManager.sendMessageToDevice(to: hub.id, message: [UInt8](data)) // Convert Data back to [UInt8]
        } else {
            print("Device not connected")
        }
    }
    
    private func deleteHub(at offsets: IndexSet) {
        bluetoothManager.storedHubs.remove(atOffsets: offsets)
    }
}

struct GroupingView_Previews: PreviewProvider {
    static var previews: some View {
        GroupingView(showGrouping: .constant(true))
            .environmentObject(BluetoothManager.shared)
    }
}
