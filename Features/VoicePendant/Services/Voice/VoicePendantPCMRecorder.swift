//
//  VoicePendantPCMRecorder.swift
//  Limi
//
//  Captures microphone PCM at 16 kHz mono Int16 LE in 640-byte (20 ms) chunks.
//

import AVFoundation
import Foundation

final class VoicePendantPCMRecorder {
    private let engine = AVAudioEngine()
    private let targetFormat: AVAudioFormat
    private var converter: AVAudioConverter?
    private var pending = Data()
    private var onChunk: ((Data) -> Void)?
    private var onLevel: ((Float) -> Void)?
    private let chunkSize = VoicePendantVoiceConfiguration.micChunkBytes

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: VoicePendantVoiceConfiguration.micSampleRate,
            channels: VoicePendantVoiceConfiguration.micChannels,
            interleaved: true
        )!
    }

    func start(onChunk: @escaping (Data) -> Void, onLevel: ((Float) -> Void)? = nil) async throws {
        let granted = await Self.requestPermission()
        guard granted else { throw VoicePendantVoiceError.microphoneUnavailable }
        try startCapture(onChunk: onChunk, onLevel: onLevel)
    }

    private func startCapture(onChunk: @escaping (Data) -> Void, onLevel: ((Float) -> Void)?) throws {
        self.onChunk = onChunk
        self.onLevel = onLevel
        pending.removeAll(keepingCapacity: true)

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard let audioConverter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw VoicePendantVoiceError.microphoneUnavailable
        }
        converter = audioConverter

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            self?.handleInput(buffer: buffer)
        }

        engine.prepare()
        try engine.start()
    }

    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil
        pending.removeAll(keepingCapacity: false)
        onChunk = nil
        onLevel = nil
    }

    private func handleInput(buffer: AVAudioPCMBuffer) {
        guard let converter else { return }
        reportLevel(from: buffer)

        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * VoicePendantVoiceConfiguration.micSampleRate / buffer.format.sampleRate
        ) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: max(frameCapacity, 256)) else {
            return
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        converter.convert(to: converted, error: &error, withInputFrom: inputBlock)
        guard error == nil, converted.frameLength > 0 else { return }

        appendPCM(from: converted)
    }

    private func appendPCM(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.int16ChannelData else { return }
        let byteCount = Int(buffer.frameLength) * MemoryLayout<Int16>.size
        pending.append(Data(bytes: channelData[0], count: byteCount))

        while pending.count >= chunkSize {
            let chunk = pending.prefix(chunkSize)
            pending.removeFirst(chunkSize)
            onChunk?(Data(chunk))
        }
    }

    private func reportLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }
        var sum: Float = 0
        let samples = channelData[0]
        for index in 0..<frames {
            sum += abs(samples[index])
        }
        let average = sum / Float(frames)
        onLevel?(min(1, average * 8))
    }

    private static func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            if #available(iOS 17.0, *) {
                AVAudioApplication.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            } else {
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
        }
    }
}
