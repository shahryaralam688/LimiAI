//
//  VoicePendantPCMPlayer.swift
//  Limi
//
//  Plays backend speaker PCM at 24 kHz mono Int16 LE.
//

import AVFoundation
import Foundation

final class VoicePendantPCMPlayer {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let format: AVAudioFormat
    private var isRunning = false

    init() {
        format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: VoicePendantVoiceConfiguration.speakerSampleRate,
            channels: VoicePendantVoiceConfiguration.speakerChannels,
            interleaved: true
        )!
    }

    func prepare() throws {
        guard !isRunning else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        engine.prepare()
        try engine.start()
        playerNode.play()
        isRunning = true
    }

    func enqueue(_ data: Data) {
        guard isRunning, !data.isEmpty else { return }
        let frameCount = AVAudioFrameCount(data.count / MemoryLayout<Int16>.size)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }

        buffer.frameLength = frameCount
        data.withUnsafeBytes { raw in
            guard let base = raw.baseAddress, let channel = buffer.int16ChannelData?[0] else { return }
            memcpy(channel, base, data.count)
        }
        playerNode.scheduleBuffer(buffer, completionHandler: nil)
    }

    func stop() {
        guard isRunning else { return }
        playerNode.stop()
        engine.stop()
        engine.detach(playerNode)
        isRunning = false
    }
}
