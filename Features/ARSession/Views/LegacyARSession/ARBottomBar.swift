import SwiftUI

struct ARBottomBar: View {
    var body: some View {
        VStack(spacing: 10) {
            // Camera-style screenshot button
            Button(action: {
                ARSnapshotManager.shared.captureScreen()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.appTextPrimary.opacity(0.9))
                        .frame(width: 70, height: 70)
                    Circle()
                        .stroke(Color.themeBlack.opacity(0.4), lineWidth: 3)
                        .frame(width: 70, height: 70)
                    Image(systemName: "camera")
                        .font(LimiTypography.title2)
                        .foregroundColor(.appTextPrimary)
                }
            }
            
            Text("Tap To Take A Picture ")
                .foregroundColor(.appTextPrimary)
                .padding(.bottom)
            // Model picker bar
           ARModelList()
        }
        .padding()
        .ignoresSafeArea()
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }
}

#Preview {
    ARBottomBar()
}
