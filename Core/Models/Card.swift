import Foundation

struct Card: Identifiable {
    var id = UUID()
    var imageName: [String]
    var title: String
    var price: Double
    var description: String
    var objectName: String
    var size: String
    var color: String
}
