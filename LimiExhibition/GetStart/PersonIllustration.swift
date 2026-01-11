import SwiftUI

struct PersonIllustration: View {
    let isDeaf: Bool
    
    var body: some View {
        Canvas { context, size in
            // Common elements (head and body)
            let head = Path(ellipseIn: CGRect(x: 20, y: 10, width: 40, height: 40))
            let body = Path(roundedRect: CGRect(x: 30, y: 50, width: 20, height: 30), cornerRadius: 5)
            
            // Deaf person illustration
            if isDeaf {
                // Head
                context.stroke(head, with: .color(.black), lineWidth: 2)
                context.fill(head, with: .linearGradient(Gradient(colors: [.gray, .black]), startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1)))
                
                // Body
                context.stroke(body, with: .color(.black), lineWidth: 2)
                context.fill(body, with: .linearGradient(Gradient(colors: [.gray, .black]), startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1)))
                
                // Phone
                let phone = Path(roundedRect: CGRect(x: 25, y: 60, width: 15, height: 20), cornerRadius: 3)
                context.stroke(phone, with: .color(.black), lineWidth: 2)
                context.fill(phone, with: .linearGradient(Gradient(colors: [.white, .gray]), startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1)))
            }
            // Sign language interpreter
            else {
                // Head
                context.stroke(head, with: .color(.black), lineWidth: 2)
                context.fill(head, with: .linearGradient(Gradient(colors: [.gray, .black]), startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1)))
                
                // Body
                context.stroke(body, with: .color(.black), lineWidth: 2)
                context.fill(body, with: .linearGradient(Gradient(colors: [.gray, .black]), startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1)))
                
                // Arms outstretched (left arm)
                let leftArm = Path { path in
                    path.move(to: CGPoint(x: 30, y: 55))
                    path.addLine(to: CGPoint(x: 10, y: 50))
                    path.addLine(to: CGPoint(x: 10, y: 55))
                    path.addLine(to: CGPoint(x: 30, y: 60))
                    path.closeSubpath()
                }
                context.stroke(leftArm, with: .color(.black), lineWidth: 2)
                context.fill(leftArm, with: .linearGradient(Gradient(colors: [.gray, .black]), startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1)))
                
                // Arms outstretched (right arm)
                let rightArm = Path { path in
                    path.move(to: CGPoint(x: 50, y: 55))
                    path.addLine(to: CGPoint(x: 70, y: 50))
                    path.addLine(to: CGPoint(x: 70, y: 55))
                    path.addLine(to: CGPoint(x: 50, y: 60))
                    path.closeSubpath()
                }
                context.stroke(rightArm, with: .color(.black), lineWidth: 2)
                context.fill(rightArm, with: .linearGradient(Gradient(colors: [.gray, .black]), startPoint: CGPoint(x: 0.5, y: 0), endPoint: CGPoint(x: 0.5, y: 1)))
            }
        }
        .frame(width: 60, height: 60)
    }
}

struct ProductionIllustration: View {
    let isSelected: Bool
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.charlestonGreen)

                .frame(width: 60, height: 60)
            
            Image(systemName: "building.2")
                .font(.system(size: 40))
                .foregroundColor(Color.alabaster)
        }
    }
}
struct PersonIllustration_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            PersonIllustration(isDeaf: true)
                .background(Color.purple)
            
            PersonIllustration(isDeaf: false)
                .background(Color.purple)
        }
    }
}
