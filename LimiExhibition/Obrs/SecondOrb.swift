import SwiftUI

struct GSAPLayoutAnimation: View {
    @State private var currentLayout = 0
    @State private var opacity: Double = 1
    private let layouts = ["final", "plain", "columns", "grid"]
    private let letters = "LIMI".map { String($0) }
    
    var body: some View {
        VStack {
            // Main container that changes layout
            containerView
                .onAppear {
                    startAnimation()
                }
        }
    }
    
    @ViewBuilder
    private var containerView: some View {
        switch currentLayout {
        case 0: // Final layout (stacked)
            HStack(spacing: 0) {
                ForEach(0..<letters.count, id: \.self) { index in
                    Text(letters[index])
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.themeWhite)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Color.blue))
                        .opacity(opacity)
                }
            }
            
        case 1: // Plain layout
            HStack(spacing: 20) {
                ForEach(0..<letters.count, id: \.self) { index in
                    Text(letters[index])
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.themeWhite)
                        .opacity(opacity)
                }
            }
            
        case 2: // Columns layout
            VStack(spacing: 10) {
                ForEach(0..<letters.count, id: \.self) { index in
                    Text(letters[index])
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.themeWhite)
                        .frame(width: 100, height: 100)
                        .background(Rectangle().fill(Color.green))
                        .opacity(opacity)
                }
            }
            
        case 3: // Grid layout
            LazyVGrid(columns: [GridItem(), GridItem()], spacing: 20) {
                ForEach(0..<letters.count, id: \.self) { index in
                    Text(letters[index])
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.themeWhite)
                        .frame(width: 80, height: 80)
                        .background(Circle().fill(Color.orange))
                        .opacity(opacity)
                }
            }
            .padding()
            
        default:
            EmptyView()
        }
    }
    
    private func startAnimation() {
        let duration = 0.7
        let delay = currentLayout == 0 ? 3.5 : 1.5
        
        // Fade out
        withAnimation(.easeInOut(duration: 0.2)) {
            opacity = 0
        }
        
        // Change layout after fade out
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring()) {
                currentLayout = (currentLayout + 1) % layouts.count
            }
            
            // Fade in with new layout
            withAnimation(.easeInOut(duration: 0.2).delay(0.1)) {
                opacity = 1
            }
            
            // Continue to next layout after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                startAnimation()
            }
        }
    }
}

struct GSAPLayoutAnimation_Previews: PreviewProvider {
    static var previews: some View {
        GSAPLayoutAnimation()
            .preferredColorScheme(.dark)
    }
}