//
//  VoicePendantPCMFileStreamer.swift
//  Limi
//
//  Streams a local audio file to the pendant voice backend as raw 16 kHz
//  mono Int16 PCM over WebSocket (no Base64 / WAV wrapper on the wire).
//

import AVFoundation
import Foundation

enum VoicePendantPCMFileStreamer {
    enum StreamError: LocalizedError {
        case handshakeTimeout
        case unreadableAudio
        case conversionFailed

        var errorDescription: String? {
            switch self {
            case .handshakeTimeout: return "Pendant voice service did not respond in time."
            case .unreadableAudio: return "Could not read the audio file."
            case .conversionFailed: return "Could not convert audio for the pendant voice service."
            }
        }
    }

    static func stream(fileURL: URL, deviceID: String) async throws {
        let chunks = try pcmChunks(from: fileURL)
        let webSocket = VoicePendantWebSocketService()
        let endpoint = VoicePendantVoiceConfiguration.webSocketURL(deviceID: deviceID)
        let gate = CompletionGate()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            gate.bind(continuation)

            webSocket.onClosed = { error in
                if let error {
                    gate.fail(error)
                }
            }

            webSocket.onText = { text in
                guard let data = text.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = json["type"] as? String,
                      type == "backend_ready" else { return }

                Task {
                    do {
                        try await webSocket.sendJSON(VoicePendantVoiceConfiguration.helloPayload)
                        for chunk in chunks {
                            try await webSocket.sendBinary(chunk)
                        }
                        print("🔊 [VoicePendantVoice] Sent \(chunks.count) PCM chunks (\(fileURL.lastPathComponent)) -> \(deviceID)")
                        webSocket.disconnect()
                        gate.complete()
                    } catch {
                        webSocket.disconnect()
                        gate.fail(error)
                    }
                }
            }

            Task {
                do {
                    try await webSocket.connect(url: endpoint)
                    try await Task.sleep(nanoseconds: 10_000_000_000)
                    webSocket.disconnect()
                    gate.fail(StreamError.handshakeTimeout)
                } catch {
                    webSocket.disconnect()
                    gate.fail(error)
                }
            }
        }
    }

    private static func pcmChunks(from url: URL) throws -> [Data] {
        let asset = AVURLAsset(url: url)
        guard let track = asset.tracks(withMediaType: .audio).first else {
            throw StreamError.unreadableAudio
        }

        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsNonInterleaved: false,
            AVSampleRateKey: VoicePendantVoiceConfiguration.micSampleRate,
            AVNumberOfChannelsKey: VoicePendantVoiceConfiguration.micChannels
        ]

        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: outputSettings)
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw StreamError.conversionFailed }
        reader.add(output)
        guard reader.startReading() else { throw StreamError.conversionFailed }

        var pending = Data()
        var chunks: [Data] = []
        let chunkSize = VoicePendantVoiceConfiguration.micChunkBytes

        while reader.status == .reading {
            guard let sampleBuffer = output.copyNextSampleBuffer(),
                  let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { break }

            var length = 0
            var dataPointer: UnsafeMutablePointer<Int8>?
            guard CMBlockBufferGetDataPointer(
                blockBuffer,
                atOffset: 0,
                lengthAtOffsetOut: nil,
                totalLengthOut: &length,
                dataPointerOut: &dataPointer
            ) == kCMBlockBufferNoErr, let dataPointer else { continue }

            pending.append(Data(bytes: dataPointer, count: length))
            while pending.count >= chunkSize {
                chunks.append(Data(pending.prefix(chunkSize)))
                pending.removeFirst(chunkSize)
            }
        }

        if reader.status == .failed {
            throw reader.error ?? StreamError.conversionFailed
        }

        if !pending.isEmpty {
            var padded = pending
            padded.append(Data(repeating: 0, count: chunkSize - pending.count))
            chunks.append(padded)
        }

        guard !chunks.isEmpty else { throw StreamError.unreadableAudio }
        return chunks
    }
}

private final class CompletionGate: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Void, Error>?
    private var finished = false

    func bind(_ continuation: CheckedContinuation<Void, Error>) {
        lock.lock()
        self.continuation = continuation
        lock.unlock()
    }

    func complete() {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, let continuation else { return }
        finished = true
        continuation.resume()
    }

    func fail(_ error: Error) {
        lock.lock()
        defer { lock.unlock() }
        guard !finished, let continuation else { return }
        finished = true
        continuation.resume(throwing: error)
    }
}
