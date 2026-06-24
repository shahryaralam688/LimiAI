//
//  VoiceViewModelTests.swift
//  LimiTests
//

import Combine
import XCTest
@testable import LIMI_AI

@MainActor
final class VoiceViewModelTests: XCTestCase {

    @MainActor
    private final class MockVoiceSession: VoiceSessionControlling {
        let objectWillChange = ObservableObjectPublisher()

        @Published var connectionState: VoiceConnectionState = .disconnected
        @Published var isUserSpeaking = false
        @Published var isAssistantSpeaking = false
        @Published var lastUserVisibleError: String?
        @Published var latestTranscript: String?
        @Published var finalizedTranscript: String?
        @Published var lastToolCall: LimiToolCall?

        private(set) var startCount = 0
        private(set) var stopCount = 0

        var statePublisher: Published<VoiceConnectionState>.Publisher { $connectionState }
        var isUserSpeakingPublisher: Published<Bool>.Publisher { $isUserSpeaking }
        var isAssistantSpeakingPublisher: Published<Bool>.Publisher { $isAssistantSpeaking }
        var latestTranscriptPublisher: Published<String?>.Publisher { $latestTranscript }
        var finalizedTranscriptPublisher: Published<String?>.Publisher { $finalizedTranscript }
        var lastToolCallPublisher: Published<LimiToolCall?>.Publisher { $lastToolCall }

        func start() { startCount += 1 }
        func stop() { stopCount += 1 }
    }

    func testSendTextMessageAppendsUserMessageAndClearsInput() {
        let session = MockVoiceSession()
        let viewModel = VoiceViewModel(session: session)
        viewModel.textInput = "Hello Limi"

        viewModel.sendTextMessage()

        XCTAssertEqual(viewModel.conversationHistory.count, 1)
        XCTAssertEqual(viewModel.conversationHistory.first?.content, "Hello Limi")
        XCTAssertTrue(viewModel.conversationHistory.first?.isUser == true)
        XCTAssertEqual(viewModel.textInput, "")
        XCTAssertTrue(viewModel.isChatMode)
    }

    func testToggleVoiceStartsWhenDisconnected() {
        let session = MockVoiceSession()
        let viewModel = VoiceViewModel(session: session)

        viewModel.toggleVoice()

        XCTAssertEqual(session.startCount, 1)
        XCTAssertEqual(viewModel.assistantState, .listening)
    }

    func testToggleVoiceStopsWhenConnected() {
        let session = MockVoiceSession()
        session.connectionState = .connected
        let viewModel = VoiceViewModel(session: session)

        viewModel.toggleVoice()

        XCTAssertEqual(session.stopCount, 1)
        XCTAssertEqual(viewModel.assistantState, .idle)
    }

    func testFinalizedTranscriptAppendsAssistantMessage() {
        let session = MockVoiceSession()
        let viewModel = VoiceViewModel(session: session)

        session.finalizedTranscript = "Good evening"

        let expectation = expectation(description: "transcript appended")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            expectation.fulfill()
        }
        wait(for: [expectation], timeout: 2.0)

        XCTAssertEqual(viewModel.conversationHistory.count, 1)
        XCTAssertEqual(viewModel.conversationHistory.first?.content, "Good evening")
        XCTAssertFalse(viewModel.conversationHistory.first?.isUser == true)
        XCTAssertEqual(viewModel.currentTranscription, "")
    }

    func testConnectionLabelMapping() {
        let session = MockVoiceSession()
        let viewModel = VoiceViewModel(session: session)

        XCTAssertEqual(viewModel.connectionLabel(for: .connected), "Connected")
        XCTAssertEqual(viewModel.connectionLabel(for: .disconnected), "Offline")
    }
}
