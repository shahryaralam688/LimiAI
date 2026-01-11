import SwiftUI

struct SocketTesterView: View {
    @StateObject private var socket = LightControllingSocket.shared
    @State private var isConnected = false
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Socket Tester")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(isConnected ? "Status: Connected" : "Status: Disconnected")
                .foregroundStyle(isConnected ? .green : .red)
                .font(.subheadline)
            
            HStack(spacing: 12) {
                Button("Connect") {
                    socket.connect()
                    isConnected = true
                }
                .buttonStyle(.borderedProminent)
                
                Button("Disconnect") {
//                    socket.disconnect()
                    isConnected = false
                }
                .buttonStyle(.bordered)
            }
            
            Button("Listen For All Events") {
                socket.listenForAllEvents()
            }
            .buttonStyle(.bordered)
            
            Button("Send Sample Light Data") {
                socket.sendSampleData()
            }
            .buttonStyle(.borderedProminent)
            
            Text("Open the Xcode console to see events and acknowledgments.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
            Spacer()
        }
        .padding()
    }
}

#if DEBUG
struct SocketTesterView_Previews: PreviewProvider {
    static var previews: some View {
        SocketTesterView()
    }
}
#endif

