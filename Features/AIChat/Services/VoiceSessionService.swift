import Combine
import Foundation

/// Voice session control surface for MVVM (wraps `WebRTCVoiceClient`).
@MainActor
protocol VoiceSessionControlling: AnyObject {
    var connectionState: VoiceConnectionState { get }
    var isUserSpeaking: Bool { get }
    var isAssistantSpeaking: Bool { get }
    var lastUserVisibleError: String? { get set }
    var latestTranscript: String? { get }
    var finalizedTranscript: String? { get }
    var lastToolCall: LimiToolCall? { get }
    var statePublisher: Published<VoiceConnectionState>.Publisher { get }
    var isUserSpeakingPublisher: Published<Bool>.Publisher { get }
    var isAssistantSpeakingPublisher: Published<Bool>.Publisher { get }
    var latestTranscriptPublisher: Published<String?>.Publisher { get }
    var finalizedTranscriptPublisher: Published<String?>.Publisher { get }
    var lastToolCallPublisher: Published<LimiToolCall?>.Publisher { get }
    func start()
    func stop()
}

@MainActor
final class VoiceSessionService: ObservableObject, VoiceSessionControlling {
    private let client: WebRTCVoiceClient
    private var cancellables = Set<AnyCancellable>()

    var connectionState: VoiceConnectionState { client.state }
    var isUserSpeaking: Bool { client.isUserSpeaking }
    var isAssistantSpeaking: Bool { client.isAssistantSpeaking }
    var lastUserVisibleError: String? {
        get { client.lastUserVisibleError }
        set { client.lastUserVisibleError = newValue }
    }
    var latestTranscript: String? { client.latestTranscript }
    var finalizedTranscript: String? { client.finalizedTranscript }
    var lastToolCall: LimiToolCall? { client.lastToolCall }

    var statePublisher: Published<VoiceConnectionState>.Publisher { client.$state }
    var isUserSpeakingPublisher: Published<Bool>.Publisher { client.$isUserSpeaking }
    var isAssistantSpeakingPublisher: Published<Bool>.Publisher { client.$isAssistantSpeaking }
    var latestTranscriptPublisher: Published<String?>.Publisher { client.$latestTranscript }
    var finalizedTranscriptPublisher: Published<String?>.Publisher { client.$finalizedTranscript }
    var lastToolCallPublisher: Published<LimiToolCall?>.Publisher { client.$lastToolCall }

    init(backendBaseURL: URL) {
        client = WebRTCVoiceClient(backendBaseURL: backendBaseURL)
        client.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    func start() {
        client.start()
    }

    func stop() {
        client.stop()
    }
}
