import Foundation

enum AssistantVisualState {
    case idle
    case listening
    case thinking
    case speaking
}

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var isTyping: Bool = false
}
