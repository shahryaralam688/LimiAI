//
//  VoicePendantVoiceConfiguration.swift
//  Limi
//
//  Limi backend voice protocol constants (69.62.125.138:8000).
//

import AVFoundation
import Foundation

enum VoicePendantVoiceConfiguration {
    static let host = "69.62.125.138"
    static let port = 8000

    /// Microphone stream: 16 kHz mono Int16 LE, 20 ms = 640 bytes.
    static let micSampleRate: Double = 16_000
    static let micChannels: AVAudioChannelCount = 1
    static let micChunkBytes = 640

    /// Speaker playback: 24 kHz mono Int16 LE (~3840 bytes / 80 ms from backend).
    static let speakerSampleRate: Double = 24_000
    static let speakerChannels: AVAudioChannelCount = 1

    static let pcmFormat = "s16le"
    static let clientIdentifier = "ios"

    static var healthURL: URL {
        URL(string: "http://\(host):\(port)/health")!
    }

    static func webSocketURL(deviceID: String) -> URL {
        let encoded = deviceID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? deviceID
        return URL(string: "ws://\(host):\(port)/ws/\(encoded)")!
    }

    static var helloPayload: [String: Any] {
        [
            "type": "hello",
            "client": clientIdentifier,
            "mic_rate": Int(micSampleRate),
            "mic_channels": Int(micChannels),
            "speaker_rate": Int(speakerSampleRate),
            "speaker_channels": Int(speakerChannels),
            "format": pcmFormat
        ]
    }
}
