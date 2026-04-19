//
//  WebRTCVoiceClient.swift
//  Aura
//
//  Created by Cascade on 02/09/2025.
//

import Foundation
import Combine
import AVFAudio
import WebRTC
import AVFoundation
import MediaPlayer

// MARK: - Connection State
enum VoiceConnectionState: String {
    case disconnected = "Disconnected"
    case connecting = "Connecting"
    case connected = "Connected"
    case error = "Error"
}

// MARK: - Tool Call Models

struct LimiToolCall: Identifiable {
    let id = UUID()
    let callId: String
    let name: String
    let action: String
    let mode: String?
    let brightness: Int?
    let room: String?
    let userText: String?
    let timestamp: Date = Date()

    var displayText: String {
        switch action {
        case "turn_on":
            return "Turning on lights\(room.map { " in \($0)" } ?? "")"
        case "turn_off":
            return "Turning off lights\(room.map { " in \($0)" } ?? "")"
        case "set_mode":
            return "Setting \(mode ?? "mode")\(room.map { " in \($0)" } ?? "")"
        case "set_brightness":
            let pct = brightness.map { "\($0)" } ?? "—"
            return "Setting brightness to \(pct)\(room.map { " in \($0)" } ?? "")"
        case "whatsapp_draft":
            let who = room ?? "contact"
            return "Opening WhatsApp to message \(who)"
        default:
            return "Controlling lights\(room.map { " in \($0)" } ?? "")"
        }
    }
}

// MARK: - WebRTC Client
final class WebRTCVoiceClient: NSObject, ObservableObject {
    // Public
    @Published private(set) var state: VoiceConnectionState = .disconnected
    @Published private(set) var logs: [String] = []
    // Latest live transcript chunk to drive UI
    @Published var latestTranscript: String? = nil
    // Finalized transcript segments to append to history
    @Published var finalizedTranscript: String? = nil
    // High-level speaking state for UI (user/assistant/idle)
    @Published var isUserSpeaking: Bool = false
    @Published var isAssistantSpeaking: Bool = false
    /// Short message for alerts when connection fails (auth, session, etc.).
    @Published var lastUserVisibleError: String?
    /// Latest tool call from OpenAI (e.g. control_light) for UI feedback.
    @Published var lastToolCall: LimiToolCall?

    // Configure this to your backend base URL (must be HTTPS in production)
    private let backendBaseURL: URL
    // Optional webhook to forward conversation events
    private let webhookURL: URL? = URL(string: "https://dev.api.limitless-lighting.co.uk/limi-ai/webhook")
    // RTC
    private var factory: RTCPeerConnectionFactory!
    private var peerConnection: RTCPeerConnection?
    private var localAudioTrack: RTCAudioTrack?
    private var dataChannel: RTCDataChannel?

    // Reconnection
    private var reconnectAttempts = 0
    private var maxReconnectAttempts = 3
    private var reconnectWorkItem: DispatchWorkItem?

    // Session (populated from backend /limi-ai/session response)
    private var ephemeralKey: String?
    private var sessionId: String?
    private var sessionModel: String?

    /// After each new connection, send one `response.create` so the assistant can speak first (e.g. hello) without the user talking.
    private var pendingProactiveGreetingForThisConnection = true
    /// Avoid duplicate flush if `dataChannelDidChangeState` fires more than once while open.
    private var didFlushContextOnDataChannelOpen = false
    /// Client-registered Realtime tools (merges with `session.created` / `session.updated` tool lists).
    private var cachedRealtimeSessionTools: [[String: Any]] = []
    private var didRegisterClientWhatsAppToolThisConnection = false
    private var receivedRealtimeSessionSnapshot = false

    // Queues
    private let workQueue = DispatchQueue(label: "webrtc.voice.client")

    // Notifications
    private var notificationObservers: [NSObjectProtocol] = []
    
    // Remote command center
    private var remoteCommandCenterConfigured = false
    private let commandCenter = MPRemoteCommandCenter.shared()

    init(backendBaseURL: URL) {
        self.backendBaseURL = backendBaseURL
        super.init()
        setupFactory()
        configureAudioSessionForLoudspeaker()
        registerForAudioSessionNotifications()
        setupNowPlaying(isActive: false)
    }
    
    /// Send minimal webhook body strictly as { "text": "..." }
    private func sendTextBody(_ text: String) {
        guard let webhookURL else {
            log("Webhook skipped: webhookURL is nil")
            return
        }
        let body: [String: Any] = ["text": text]
        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [])
            var req = URLRequest(url: webhookURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            if let token = webhookTokenHeaderValue() {
                req.setValue(token, forHTTPHeaderField: "Authorization")
            }
            req.httpBody = data
            
            if let jsonString = String(data: data, encoding: .utf8) {
                log("➡️ Webhook Request (text-only): POST \(webhookURL.absoluteString) Body: \(jsonString)")
            }
            
            URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
                if let http = resp as? HTTPURLResponse {
                    self?.log("⬅️ Webhook Response Status: \(http.statusCode) from \(webhookURL.host ?? "?")")
                }
                if let err {
                    self?.log("❌ Webhook error: \(err.localizedDescription)")
                    return
                }
            }.resume()
        } catch {
            log("Webhook JSON encode error: \(error.localizedDescription)")
        }
    }

    deinit {
        removeAudioSessionNotifications()
    }

    // MARK: Public API
    func start() {
        guard state != .connecting && state != .connected else { return }
        guard AuthManager.shared.authorizationHeaderValue() != nil else {
            let msg = "Sign in to use voice — Limi couldn’t find your session."
            log("❌ start() aborted: no auth token")
            DispatchQueue.main.async {
                self.lastUserVisibleError = msg
                self.state = .error
            }
            return
        }
        lastUserVisibleError = nil
        pendingProactiveGreetingForThisConnection = true
        state = .connecting
        log("🚀 START — backendBaseURL: \(backendBaseURL.absoluteString)")
        postWebhook(event: "session_start", payload: [:])
        requestMicPermission { [weak self] granted in
            guard let self else { return }
            if !granted {
                self.fail("Microphone permission denied", allowReconnect: false)
                return
            }
            self.configureAVAudioSession()
            self.configureRemoteCommandCenter()
            self.fetchEphemeralKey { [weak self] result in
                switch result {
                case .success(let key):
                    self?.ephemeralKey = key
                    self?.createPeerAndConnect()
                case .failure(let error):
                    self?.fail(
                        "Token error: \(error.localizedDescription)",
                        allowReconnect: Self.errorAllowsReconnect(after: error)
                    )
                }
            }
        }
    }

    /// Auth/session identity failures cannot be fixed by reconnecting; avoid reconnect storms and log spam.
    private static func errorAllowsReconnect(after error: Error) -> Bool {
        let ns = error as NSError
        if ns.domain == "auth" { return false }
        if ns.domain == "limi.session" && ns.code == 401 { return false }
        return true
    }

    func stop() {
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        ephemeralKey = nil
        sessionId = nil
        sessionModel = nil
        tearDownPeer()
        state = .disconnected
        log("Stopped voice session")
        postWebhook(event: "session_stop", payload: [:])
        teardownRemoteCommandCenter()
        setupNowPlaying(isActive: false)
        deactivateAudioSession()
    }

    // MARK: Setup
    private func setupFactory() {
        RTCInitializeSSL()
        let encoderFactory = RTCDefaultVideoEncoderFactory()
        let decoderFactory = RTCDefaultVideoDecoderFactory()
        factory = RTCPeerConnectionFactory(encoderFactory: encoderFactory, decoderFactory: decoderFactory)
    }

    private func configureAVAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Enhanced audio session configuration with better error handling
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
            try session.setActive(true, options: [])
            log("Audio session configured successfully")
        } catch let error as NSError {
            log("Audio session error: \(error.localizedDescription) (code: \(error.code))")
            // Attempt recovery with fallback configuration
            do {
                try session.setCategory(.playAndRecord, options: [.defaultToSpeaker])
                try session.setActive(true, options: [])
                log("Audio session configured with fallback settings")
            } catch {
                log("Audio session fallback failed: \(error.localizedDescription)")
            }
        }
    }

    private func configureAudioSessionForLoudspeaker() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
            try session.setActive(true)
        } catch {
            print("Failed to set audio session category to loudspeaker: \(error)")
        }
    }

    // MARK: Audio Session Observing & Route Handling
    private func registerForAudioSessionNotifications() {
        let center = NotificationCenter.default
        let obs1 = center.addObserver(forName: AVAudioSession.interruptionNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleAudioSessionInterruption(note)
        }
        let obs2 = center.addObserver(forName: AVAudioSession.routeChangeNotification, object: nil, queue: .main) { [weak self] note in
            self?.handleAudioRouteChange(note)
        }
        let obs3 = center.addObserver(forName: AVAudioSession.mediaServicesWereLostNotification, object: nil, queue: .main) { [weak self] _ in
            self?.log("Audio media services were lost — will attempt to restore")
        }
        let obs4 = center.addObserver(forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main) { [weak self] _ in
            self?.log("Audio media services were reset — reconfiguring session")
            self?.reconfigureAudioSessionAfterReset()
        }
        notificationObservers.append(contentsOf: [obs1, obs2, obs3, obs4])
    }

    private func removeAudioSessionNotifications() {
        let center = NotificationCenter.default
        for obs in notificationObservers { center.removeObserver(obs) }
        notificationObservers.removeAll()
    }

    private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeRaw = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeRaw) else { return }

        switch type {
        case .began:
            log("🔇 Audio interruption began - pausing microphone")
            // Gracefully handle interruption without full shutdown
            postWebhook(event: "audio_interrupted", payload: ["type": "began"])
        case .ended:
            let optionsRaw = info[AVAudioSessionInterruptionOptionKey] as? UInt
            let options = AVAudioSession.InterruptionOptions(rawValue: optionsRaw ?? 0)
            log("🔊 Audio interruption ended, options=\(options)")
            
            // Enhanced recovery logic
            if options.contains(.shouldResume) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.recoverFromAudioInterruption()
                }
            } else {
                log("Audio interruption ended but should not resume automatically")
            }
            postWebhook(event: "audio_interrupted", payload: ["type": "ended", "shouldResume": options.contains(.shouldResume)])
        @unknown default:
            break
        }
    }

    private func handleAudioRouteChange(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonRaw = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonRaw) else { return }
        log("🔀 Route change: reason=\(reason.rawValue)")
        updateAudioRouteForCurrentOutputs()
    }

    private func reconfigureAudioSessionAfterReset() {
        // Re-apply category and activation, then update route.
        configureAudioSessionForLoudspeaker()
        updateAudioRouteForCurrentOutputs()
    }

    private func activateAudioSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true, options: [])
            updateAudioRouteForCurrentOutputs()
            log("Audio session reactivated successfully")
        } catch {
            log("Audio session reactivate error: \(error.localizedDescription)")
            // Attempt recovery without throwing error
            recoverFromAudioSessionError()
        }
    }
    
    private func recoverFromAudioInterruption() {
        log("Attempting recovery from audio interruption")
        configureAVAudioSession()
        updateAudioRouteForCurrentOutputs()
        
        // Recreate audio track if connection is still active
        if state == .connected, let pc = peerConnection {
            recreateLocalAudioTrack(for: pc)
        }
    }
    
    private func recoverFromAudioSessionError() {
        log("Attempting recovery from audio session error")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.configureAVAudioSession()
        }
    }
    
    private func recreateLocalAudioTrack(for peerConnection: RTCPeerConnection) {
        // Remove old track
        if let oldTrack = localAudioTrack {
            let senders = peerConnection.senders.filter { $0.track?.trackId == oldTrack.trackId }
            for sender in senders {
                peerConnection.removeTrack(sender)
            }
        }
        
        // Create and add new track
        let newTrack = createLocalAudioTrack()
        localAudioTrack = newTrack
        peerConnection.add(newTrack, streamIds: ["stream0"])
        log("Local audio track recreated successfully")
    }

    private func updateAudioRouteForCurrentOutputs() {
        let session = AVAudioSession.sharedInstance()
        let outputs = session.currentRoute.outputs
        let hasHeadphonesOrBT = outputs.contains { out in
            switch out.portType {
            case .headphones, .headsetMic, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
                return true
            default:
                return false
            }
        }

        do {
            if hasHeadphonesOrBT {
                // Respect external routes; no override.
                try session.overrideOutputAudioPort(.none)
                log("🔈 Using external audio route: \(outputs.map { $0.portType.rawValue }.joined(separator: ", "))")
            } else {
                // Ensure loudspeaker when on device only.
                try session.overrideOutputAudioPort(.speaker)
                log("📢 Forced output to loudspeaker")
            }
        } catch {
            log("Audio route override error: \(error.localizedDescription)")
        }
    }

    // MARK: Mic
    private func requestMicPermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            let permission = AVAudioApplication.shared.recordPermission

            log("Checking microphone permission status: \(permission.rawValue)")

            switch permission {
            case .granted:
                log("Microphone permission already granted")
                completion(true)
            case .denied:
                log("Microphone permission denied - user needs to enable in Settings")
                postWebhook(event: "mic_permission_denied", payload: [:])
                completion(false)
            case .undetermined:
                log("Requesting microphone permission from user")
                AVAudioApplication.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        self?.log("Microphone permission request result: \(granted)")
                        self?.postWebhook(event: "mic_permission_requested", payload: ["granted": granted])
                        completion(granted)
                    }
                }
            @unknown default:
                log("Unknown microphone permission state")
                completion(false)
            }
        } else {
            let session = AVAudioSession.sharedInstance()

            log("Checking microphone permission status: \(session.recordPermission.rawValue)")

            switch session.recordPermission {
            case .granted:
                log("Microphone permission already granted")
                completion(true)
            case .denied:
                log("Microphone permission denied - user needs to enable in Settings")
                postWebhook(event: "mic_permission_denied", payload: [:])
                completion(false)
            case .undetermined:
                log("Requesting microphone permission from user")
                session.requestRecordPermission { [weak self] granted in
                    DispatchQueue.main.async {
                        self?.log("Microphone permission request result: \(granted)")
                        self?.postWebhook(event: "mic_permission_requested", payload: ["granted": granted])
                        completion(granted)
                    }
                }
            @unknown default:
                log("Unknown microphone permission state")
                completion(false)
            }
        }
    }

    private func createLocalAudioTrack() -> RTCAudioTrack {
        let audioSource = factory.audioSource(with: RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil))
        let track = factory.audioTrack(with: audioSource, trackId: "ARDAMSa0")
        return track
    }

    // MARK: Peer
    private func createPeerAndConnect() {
        let config = RTCConfiguration()
        config.sdpSemantics = .unifiedPlan
        config.iceServers = [
            RTCIceServer(urlStrings: ["stun:stun.l.google.com:19302"]) // Add TURN in production
        ]
        let constraints = RTCMediaConstraints(mandatoryConstraints: nil,
                                              optionalConstraints: ["DtlsSrtpKeyAgreement": "true"])
        let pc = factory.peerConnection(with: config, constraints: constraints, delegate: self)
        self.peerConnection = pc

        // Local audio
        let track = createLocalAudioTrack()
        self.localAudioTrack = track
        // Add the microphone track to the peer connection
        _ = pc?.add(track, streamIds: ["stream0"])

        // Create data channel for JSON/text events from OpenAI
        let dcConfig = RTCDataChannelConfiguration()
        dcConfig.isOrdered = true
        if let dc = pc?.dataChannel(forLabel: "oai-events", configuration: dcConfig) {
            dc.delegate = self
            self.dataChannel = dc
            log("DataChannel created: label=\(dc.label)")
        } else {
            log("DataChannel creation failed")
        }

        // Offer
        let offerConstraints = RTCMediaConstraints(mandatoryConstraints: [
            "OfferToReceiveAudio": "true",
            "VoiceActivityDetection": "true"
        ], optionalConstraints: nil)
        pc?.offer(for: offerConstraints) { [weak self] sdp, error in
            guard let self else { return }
            if let error {
                self.fail("Offer error: \(error.localizedDescription)")
                return
            }
            guard let sdp else {
                self.fail("Offer error: nil SDP")
                return
            }
            pc?.setLocalDescription(sdp) { [weak self] err in
                if let err { self?.fail("setLocalDescription error: \(err.localizedDescription)"); return }
                self?.sendOfferToBackend(offer: sdp)
            }
        }
    }

    private func tearDownPeer() {
        log("Tearing down peer connection gracefully")
        
        // Gracefully close data channel
        if let dc = dataChannel {
            dc.delegate = nil
            if dc.readyState == .open {
                dc.close()
            }
            dataChannel = nil
        }
        
        // Remove local audio track before closing connection
        if let track = localAudioTrack, let pc = peerConnection {
            let senders = pc.senders.filter { $0.track?.trackId == track.trackId }
            for sender in senders {
                pc.removeTrack(sender)
            }
        }
        localAudioTrack = nil
        
        // Close peer connection
        if let pc = peerConnection {
            pc.close()
        }
        peerConnection = nil

        didFlushContextOnDataChannelOpen = false
        cachedRealtimeSessionTools = []
        didRegisterClientWhatsAppToolThisConnection = false
        receivedRealtimeSessionSnapshot = false

        log("Peer connection torn down successfully")
    }

    // MARK: Backend

    /// Backend controls model, voice, and instructions; the client may send `session.update` to add tools (e.g. WhatsApp) when missing.
    /// API may return either a flat object or `{ "success": true, "data": { ... } }`.
    private struct SessionDataPayload: Decodable {
        let key: String
        let sessionId: String?
        let expiresAt: Int?
        let model: String?
        let voice: String?
        let instructions: String?
    }

    private struct SessionEnvelope: Decodable {
        let success: Bool?
        let data: SessionDataPayload?
    }

    private static func decodeSessionPayload(from data: Data) throws -> SessionDataPayload {
        let decoder = JSONDecoder()
        if let envelope = try? decoder.decode(SessionEnvelope.self, from: data), let inner = envelope.data {
            return inner
        }
        return try decoder.decode(SessionDataPayload.self, from: data)
    }

    private func fetchEphemeralKey(completion: @escaping (Result<String, Error>) -> Void) {
        // Check if we have a valid authentication token (Bearer aligned with other API routes)
        guard let authHeader = AuthManager.shared.authorizationHeaderValue() else {
            log("❌ No valid authentication token available")
            let msg = "Sign in to use voice — Limi couldn’t find your session."
            DispatchQueue.main.async {
                self.lastUserVisibleError = msg
                completion(.failure(NSError(domain: "auth", code: -1, userInfo: [NSLocalizedDescriptionKey: msg])))
            }
            return
        }
        
        let urlString = backendBaseURL.absoluteString.hasSuffix("/")
            ? backendBaseURL.absoluteString + "limi-ai/session"
            : backendBaseURL.absoluteString + "/limi-ai/session"
        guard let url = URL(string: urlString) else {
            log("❌ Invalid session URL: \(urlString)")
            completion(.failure(NSError(domain: "url", code: -1)))
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(authHeader, forHTTPHeaderField: "Authorization")

        log("➡️ Request: POST \(url.absoluteString)")
        log("➡️ Auth: \(authHeader.prefix(20))…")

        URLSession.shared.dataTask(with: request) { [weak self] data, resp, err in
            guard let self else { return }
            if let http = resp as? HTTPURLResponse {
                self.log("⬅️ Status: \(http.statusCode) from \(url.host ?? "?")")
                self.log("⬅️ Response Headers: \(http.allHeaderFields)")
            }

            if let err {
                self.log("❌ Session request error: \(err.localizedDescription)")
                DispatchQueue.main.async {
                    self.lastUserVisibleError = "Network error — check your connection and try again."
                    completion(.failure(err))
                }
                return
            }
            if let http = resp as? HTTPURLResponse, !(200 ... 299).contains(http.statusCode) {
                let responseBody = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
                self.log("❌ Session endpoint HTTP \(http.statusCode) — URL: \(url.absoluteString)")
                self.log("❌ Response body: \(responseBody)")
                let msg: String
                if http.statusCode == 401 {
                    msg = "Session expired or not allowed. Sign in again to use voice."
                } else {
                    msg = "Could not start voice (error \(http.statusCode)). Tap to retry."
                }
                DispatchQueue.main.async {
                    self.lastUserVisibleError = msg
                    completion(.failure(NSError(domain: "limi.session", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
                return
            }
            guard let data else {
                self.log("❌ Session response had empty body")
                DispatchQueue.main.async {
                    self.lastUserVisibleError = "Invalid response from voice service."
                    completion(.failure(NSError(domain: "session", code: -1)))
                }
                return
            }

            if let body = String(data: data, encoding: .utf8) {
                self.log("⬅️ Body: \(body)")
            }

            do {
                let session = try Self.decodeSessionPayload(from: data)
                self.sessionId = session.sessionId
                self.sessionModel = session.model
                self.log("✅ Session: key=\(session.key.prefix(12))… id=\(session.sessionId ?? "-") model=\(session.model ?? "-") voice=\(session.voice ?? "-")")
                DispatchQueue.main.async { completion(.success(session.key)) }
            } catch {
                self.log("❌ Session decode error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.lastUserVisibleError = "Voice session response was invalid. Try again later."
                    completion(.failure(error))
                }
            }
        }.resume()
    }

    private func sendOfferToBackend(offer: RTCSessionDescription) {
        guard let key = ephemeralKey else { fail("Missing ephemeral key"); return }
        let model = sessionModel ?? "gpt-realtime"
        guard let url = URL(string: AppURLs.External.openAIRealtime(model: model)) else { fail("Invalid OpenAI URL"); return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("realtime=v1", forHTTPHeaderField: "OpenAI-Beta")
        request.setValue("application/sdp", forHTTPHeaderField: "Content-Type")
        request.setValue("application/sdp", forHTTPHeaderField: "Accept")
        request.httpBody = offer.sdp.data(using: .utf8)

        // Log outgoing request
        log("➡️ Request: POST \(url.absoluteString) [application/sdp] body=\(offer.sdp.count) chars\n📝 SDP (first 200): \(String(offer.sdp.prefix(200)))…")

        URLSession.shared.dataTask(with: request) { [weak self] data, resp, err in
            guard let self else { return }
            if let http = resp as? HTTPURLResponse {
                self.log("⬅️ OpenAI Status: \(http.statusCode) from \(url.absoluteString)")
                if !(200...299).contains(http.statusCode) {
                    let body = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
                    self.log("❌ OpenAI error \(http.statusCode): \(body)")
                }
            }
            if let err { self.fail("Offer POST error: \(err.localizedDescription)"); return }
            guard let data else { self.fail("Empty answer body"); return }
            if let contentType = (resp as? HTTPURLResponse)?.allHeaderFields["Content-Type"] as? String, contentType.contains("application/json"),
               let json = String(data: data, encoding: .utf8) {
                self.fail("OpenAI error JSON: \(json)")
                return
            }
            guard let answerSDP = String(data: data, encoding: .utf8) else {
                self.fail("Answer not UTF-8 text")
                return
            }
            self.log("⬅️ Answer SDP size=\(answerSDP.count) chars\n📝 SDP (first 200): \(String(answerSDP.prefix(200)))…")
            let remote = RTCSessionDescription(type: .answer, sdp: answerSDP)
            self.peerConnection?.setRemoteDescription(remote) { [weak self] err in
                if let err { self?.fail("setRemoteDescription error: \(err.localizedDescription)"); return }
                DispatchQueue.main.async {
                    self?.state = .connected
                    self?.reconnectAttempts = 0
                    self?.log("Connected")
                    self?.postWebhook(event: "connected", payload: [:])
                    self?.setupNowPlaying(isActive: true)
                }
            }
        }.resume()
    }

    private func postLocalIceCandidate(_ candidate: RTCIceCandidate) {
        // No-op for OpenAI Realtime WebRTC — ICE trickling handled internally by the peer connection
        log("ICE candidate generated (not posted): sdpMid=\(candidate.sdpMid ?? "nil"), index=\(candidate.sdpMLineIndex)")
    }

    // MARK: Logging
    private func log(_ message: String) {
        DispatchQueue.main.async {
            let line = "[\(Date())] \(message)"
            self.logs.append(line)
            // Also mirror to Xcode console
            print(line)
        }
    }

    // MARK: Webhook Forwarding
    
    /// Send webhook request to the configured endpoint with text or JSON payload
    func sendWebhook(text: String? = nil, json: [String: Any]? = nil) {
        guard let webhookURL else {
            log("Webhook skipped: webhookURL is nil")
            return
        }
        
        var body: [String: Any] = [
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "state": state.rawValue
        ]
        
        // Add text payload if provided
        if let text = text {
            body["text"] = text
        }
        
        // Add JSON payload if provided
        if let json = json {
            body["json"] = json
        }
        
        // Ensure at least one payload type is provided
        guard text != nil || json != nil else {
            log("Webhook skipped: no payload provided")
            return
        }
        
        do {
            let data = try JSONSerialization.data(withJSONObject: body, options: [.prettyPrinted])
            var req = URLRequest(url: webhookURL)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            if let token = webhookTokenHeaderValue() {
                req.setValue(token, forHTTPHeaderField: "Authorization")
            }
            req.httpBody = data
            
            // Log outgoing request
            if let jsonString = String(data: data, encoding: .utf8) {
                log("➡️ Webhook Request: POST \(webhookURL.absoluteString)\nHeaders: \(req.allHTTPHeaderFields ?? [:])\nBody: \(jsonString)")
            } else {
                log("➡️ Webhook Request: POST \(webhookURL.absoluteString) [body=\(data.count) bytes]")
            }

            URLSession.shared.dataTask(with: req) { [weak self] data, resp, err in
                // Log response status and headers
                if let http = resp as? HTTPURLResponse {
                    self?.log("⬅️ Webhook Response Status: \(http.statusCode) from \(webhookURL.host ?? "?")")
                    self?.log("⬅️ Webhook Response Headers: \(http.allHeaderFields)")
                }

                if let err {
                    self?.log("❌ Webhook error: \(err.localizedDescription)")
                    return
                }
                guard let data else {
                    self?.log("❌ Webhook response had empty body")
                    return
                }
                if let body = String(data: data, encoding: .utf8) {
                    self?.log("⬅️ Webhook Body: \(body)")
                } else {
                    self?.log("⬅️ Webhook Body (\(data.count) bytes)")
                }
            }.resume()
        } catch {
            log("Webhook JSON encode error: \(error.localizedDescription)")
        }
    }
    
    /// Legacy webhook method for backward compatibility
    private func postWebhook(event: String, payload: [String: Any]) {
        let webhookPayload: [String: Any] = [
            "event": event,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "payload": payload,
            "state": state.rawValue
        ]
        
        sendWebhook(json: webhookPayload)
    }

    private func fail(_ message: String, allowReconnect: Bool = true) {
        log("FAILURE: \(message)")
        postWebhook(event: "error", payload: ["message": message, "reconnect_attempts": reconnectAttempts])

        DispatchQueue.main.async {
            self.reconnectWorkItem?.cancel()
            self.reconnectWorkItem = nil

            if self.state != .error {
                self.state = .error
            }
            if self.lastUserVisibleError == nil {
                self.lastUserVisibleError = message
            }

            if allowReconnect, self.reconnectAttempts < self.maxReconnectAttempts {
                self.scheduleReconnect()
            } else {
                if !allowReconnect {
                    self.log("Not scheduling reconnect (sign-in required or non-recoverable error).")
                } else {
                    self.log("Max reconnect attempts reached - not scheduling further reconnects")
                }
                self.tearDownPeer()
                self.deactivateAudioSession()
            }
        }
    }
    
    private func deactivateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            log("Audio session deactivated")
        } catch {
            log("Failed to deactivate audio session: \(error.localizedDescription)")
        }
    }

    // MARK: - Now Playing & Remote Commands
    private func setupNowPlaying(isActive: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: "Limi AI Assistant",
            MPMediaItemPropertyArtist: isActive ? "Listening & Speaking" : "Idle",
        ]
        info[MPNowPlayingInfoPropertyIsLiveStream] = true
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommandCenter() {
        guard !remoteCommandCenterConfigured else { return }
        remoteCommandCenterConfigured = true

        let cc = commandCenter
        cc.playCommand.isEnabled = true
        cc.pauseCommand.isEnabled = true
        cc.stopCommand.isEnabled = true

        cc.playCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.start()
            self.setupNowPlaying(isActive: true)
            return .success
        }
        cc.pauseCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.stop()
            self.setupNowPlaying(isActive: false)
            return .success
        }
        cc.stopCommand.addTarget { [weak self] _ in
            guard let self else { return .commandFailed }
            self.stop()
            self.setupNowPlaying(isActive: false)
            return .success
        }
    }

    private func teardownRemoteCommandCenter() {
        guard remoteCommandCenterConfigured else { return }
        remoteCommandCenterConfigured = false

        let cc = commandCenter
        cc.playCommand.removeTarget(nil)
        cc.pauseCommand.removeTarget(nil)
        cc.stopCommand.removeTarget(nil)
    }

    /// Reconnect path only tears down the peer; if we never obtained a key (e.g. first failure was decode), fetch session again.
    private func resumeWebRTCAfterReconnectTeardown() {
        if ephemeralKey != nil {
            createPeerAndConnect()
            return
        }
        fetchEphemeralKey { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let key):
                self.ephemeralKey = key
                self.createPeerAndConnect()
            case .failure(let error):
                self.fail(
                    "Token error: \(error.localizedDescription)",
                    allowReconnect: Self.errorAllowsReconnect(after: error)
                )
            }
        }
    }

    private func scheduleReconnect() {
        if !Thread.isMainThread {
            DispatchQueue.main.async { [weak self] in self?.scheduleReconnect() }
            return
        }
        guard reconnectAttempts < maxReconnectAttempts else {
            log("Max reconnect attempts (\(maxReconnectAttempts)) reached - stopping")
            fail("Connection failed after \(maxReconnectAttempts) attempts")
            return
        }

        reconnectAttempts += 1
        let delay = min(pow(2.0, Double(reconnectAttempts)), 30.0) // Cap at 30s
        log("Reconnecting in \(Int(delay))s… (attempt \(reconnectAttempts)/\(maxReconnectAttempts))")
        
        reconnectWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            
            // Ensure audio session is still active before reconnecting
            self.configureAVAudioSession()
            
            self.tearDownPeer()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.resumeWebRTCAfterReconnectTeardown()
            }
        }
        reconnectWorkItem = work
        workQueue.asyncAfter(deadline: .now() + delay, execute: work)
        
        postWebhook(event: "reconnect_scheduled", payload: ["attempt": reconnectAttempts, "delay": delay])
    }

    /// Webhook auth header token (raw token only, no `Bearer` prefix).
    private func webhookTokenHeaderValue() -> String? {
        guard let raw = AuthManager.shared.getToken()?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        if raw.lowercased().hasPrefix("bearer ") {
            return String(raw.dropFirst(7)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return raw
    }
}

// MARK: - RTCPeerConnectionDelegate
extension WebRTCVoiceClient: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {
        log("Signaling state: \(stateChanged.rawValue)")
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        log("ICE state: \(newState.rawValue)")
        postWebhook(event: "ice_state_change", payload: ["state": newState.rawValue])
        
        switch newState {
        case .connected, .completed:
            log("ICE connection established successfully")
            reconnectAttempts = 0 // Reset on successful connection
        case .disconnected:
            log("ICE connection disconnected - attempting recovery")
            // Don't immediately reconnect, try to recover first
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                guard let self = self else { return }
                if self.peerConnection?.iceConnectionState == .disconnected {
                    self.scheduleReconnect()
                }
            }
        case .failed:
            log("ICE connection failed - scheduling reconnect")
            scheduleReconnect()
        case .checking:
            log("ICE connection checking...")
        case .new:
            log("ICE connection new")
        case .closed:
            log("ICE connection closed")
        case .count:
            log("ICE connection count state (unused)")
        @unknown default:
            log("ICE connection unknown state: \(newState.rawValue)")
        }
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {
        log("ICE gathering: \(newState.rawValue)")
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        postLocalIceCandidate(candidate)
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        log("DataChannel opened by remote: label=\(dataChannel.label)")
        self.dataChannel = dataChannel
        dataChannel.delegate = self
    }
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd rtpReceiver: RTCRtpReceiver, streams: [RTCMediaStream]) {
        // Remote audio will be played automatically by WebRTC when audio track is received and AVAudioSession is active.
        log("Remote track added: \(rtpReceiver.track?.kind ?? "?")")
    }
}

// MARK: - RTCDataChannelDelegate
extension WebRTCVoiceClient: RTCDataChannelDelegate {
    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        log("DataChannel state=\(dataChannel.readyState.rawValue) label=\(dataChannel.label)")
        postWebhook(event: "datachannel_state", payload: ["state": dataChannel.readyState.rawValue, "label": dataChannel.label])

        guard dataChannel.readyState == .open else { return }
        // Context was often skipped when `.connected` fired before the channel opened; flush here + optional first spoken turn.
        DispatchQueue.main.async { [weak self] in
            self?.flushContextAndProactiveGreeting()
        }
    }

    /// Called when the Realtime data channel first opens for this peer connection.
    private func flushContextAndProactiveGreeting() {
        guard !didFlushContextOnDataChannelOpen else { return }
        didFlushContextOnDataChannelOpen = true

        sendContextEvent()
        scheduleClientWhatsAppToolRegistration()

        guard pendingProactiveGreetingForThisConnection else { return }
        pendingProactiveGreetingForThisConnection = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.sendRealtimeResponseCreate()
        }
    }

    /// Ask the Realtime model to produce audio/text without user speech (first turn after connect).
    private func sendRealtimeResponseCreate() {
        guard let dc = dataChannel, dc.readyState == .open else {
            log("⚠️ response.create skipped — data channel not open")
            return
        }
        let event: [String: Any] = ["type": "response.create"]
        if let data = try? JSONSerialization.data(withJSONObject: event),
           dc.sendData(RTCDataBuffer(data: data, isBinary: false)) {
            log("✅ Sent response.create (proactive greeting)")
        } else {
            log("❌ Failed to send response.create")
        }
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        if buffer.isBinary {
            if let raw = String(data: buffer.data, encoding: .utf8) {
                log("📩 DataChannel binary->text: \(raw)")
                // Prepare readable text (pretty-printed JSON if possible)
                let readable: String
                var parsed: [String: Any]? = nil
                if let data = raw.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
                   let prettyString = String(data: pretty, encoding: .utf8) {
                    parsed = obj
                    readable = prettyString
                } else {
                    readable = raw
                }

                // Build envelope matching your API and send both text and JSON
                let envelope: [String: Any] = [
                    "event": "oai_event",
                    "payload": [
                        "raw_text": raw,
                        "format": "binary->text"
                    ],
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "state": state.rawValue
                ]
                sendWebhook(text: readable, json: envelope)

                // Attempt to pull transcript for UI updates
                if let obj = parsed {
                    // Update speaking state and transcript for UI
                    handleRealtimePayload(obj)
                }
            } else {
                log("📩 DataChannel received binary message (\(buffer.data.count) bytes)")
                // Send minimal envelope noting non-text binary
                let envelope: [String: Any] = [
                    "event": "oai_event_binary",
                    "payload": ["bytes": buffer.data.count],
                    "timestamp": ISO8601DateFormatter().string(from: Date()),
                    "state": state.rawValue
                ]
                sendWebhook(text: "<binary data: \(buffer.data.count) bytes>", json: envelope)
            }
        } else {
            let raw = String(decoding: buffer.data, as: UTF8.self)
            log("📩 DataChannel text: \(raw)")

            // Prepare readable text (pretty-printed JSON if possible)
            let readable: String
            var parsed: [String: Any]? = nil
            if let data = raw.data(using: .utf8),
               let obj = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let pretty = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
               let prettyString = String(data: pretty, encoding: .utf8) {
                parsed = obj
                readable = prettyString
            } else {
                readable = raw
            }

            // Build envelope matching your API and send both text and JSON
            let envelope: [String: Any] = [
                "event": "oai_event",
                "payload": [
                    "raw_text": raw,
                    "format": "text"
                ],
                "timestamp": ISO8601DateFormatter().string(from: Date()),
                "state": state.rawValue
            ]
            sendWebhook(text: readable, json: envelope)

            // Attempt to pull transcript for UI updates
            if let obj = parsed {
                // Update speaking state and transcript for UI
                handleRealtimePayload(obj)
            }
        }
    }
}

// MARK: - Context Pre-flight

extension WebRTCVoiceClient {
    /// Sends the current app context to OpenAI via `conversation.item.create`
    /// before audio streaming begins, so the AI has full awareness of the
    /// user's current screen and session state.
    func sendContextEvent() {
        guard let dc = dataChannel, dc.readyState == .open else {
            log("⚠️ DataChannel not open — skipping context pre-flight")
            return
        }

        let summary = ContextManager.shared.contextSummary()
        let event: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "message",
                "role": "user",
                "content": [[
                    "type": "input_text",
                    "text": "[System Context] \(summary)"
                ]]
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: event),
           dc.sendData(RTCDataBuffer(data: data, isBinary: false)) {
            log("✅ Sent context pre-flight: \(summary)")
        } else {
            log("❌ Failed to send context pre-flight")
        }
    }

    /// After [System Context] changes mid-session (e.g. Personalize step), ask the model for a short spoken orientation turn.
    func requestProactiveAssistantTurn() {
        guard let dc = dataChannel, dc.readyState == .open else {
            log("⚠️ requestProactiveAssistantTurn skipped — data channel not open")
            return
        }
        let event: [String: Any] = ["type": "response.create"]
        if let data = try? JSONSerialization.data(withJSONObject: event),
           dc.sendData(RTCDataBuffer(data: data, isBinary: false)) {
            log("✅ Sent response.create (proactive after context change)")
        }
    }
}

// MARK: - Realtime UI Helpers

/// OpenAI Realtime `session.tools` entry — registered from the app via `session.update` when absent.
private enum LimiRealtimeClientToolDefinitions {
    static let sendWhatsappMessage: [String: Any] = {
        let properties: [String: Any] = [
            "contact_name": [
                "type": "string",
                "description": "Recipient as in the user's address book (e.g. Ali, Ali Khan).",
            ],
            "phone": [
                "type": "string",
                "description": "Optional. Digits with country code if the user specified a number instead of a name.",
            ],
            "message": [
                "type": "string",
                "description": "Exact message body to pre-fill in WhatsApp.",
            ],
        ]
        let parameters: [String: Any] = [
            "type": "object",
            "properties": properties,
            "required": ["message"],
        ]
        return [
            "type": "function",
            "name": "send_whatsapp_message",
            "description": "Open WhatsApp with a draft message. The user taps Send in WhatsApp. Use when the user asks to send a WhatsApp. Provide contact_name from their wording when possible, or phone with country code if they gave a number. Required: message.",
            "parameters": parameters,
        ]
    }()
}

private extension WebRTCVoiceClient {
    func handleRealtimePayload(_ obj: [String: Any]) {
        let eventType = (obj["type"] as? String) ?? ""
        let lowercasedType = eventType.lowercased()

        if lowercasedType == "session.created" || lowercasedType == "session.updated" {
            if let session = obj["session"] as? [String: Any] {
                receivedRealtimeSessionSnapshot = true
                let tools = (session["tools"] as? [[String: Any]]) ?? []
                cachedRealtimeSessionTools = tools
                registerClientWhatsAppToolIfNeeded()
            }
        }

        // Transcript handling
        if let transcript = obj["transcript"] as? String, !transcript.isEmpty {
            let isFinal = (obj["final"] as? Bool == true)
                        || (obj["is_final"] as? Bool == true)
                        || (lowercasedType == "response.final")
                        || (lowercasedType == "transcript.final")
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if isFinal {
                    self.finalizedTranscript = transcript
                } else {
                    self.latestTranscript = (self.latestTranscript ?? "") + transcript
                }
            }
        }

        // Tool call handling: response.function_call_arguments.done
        if lowercasedType == "response.function_call_arguments.done" {
            handleFunctionCallDone(obj)
        }

        // Speaking state
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            switch lowercasedType {
            case "input_audio_buffer.speech_started":
                self.isUserSpeaking = true
            case "input_audio_buffer.speech_stopped":
                self.isUserSpeaking = false
            case "response.audio.delta", "response.audio.started":
                self.isAssistantSpeaking = true
            case "response.audio.completed", "response.completed":
                self.isAssistantSpeaking = false
            default:
                break
            }
        }
    }

    /// Merges `send_whatsapp_message` into the Realtime `session.tools` list via `session.update` so voice works without a backend tool definition.
    func scheduleClientWhatsAppToolRegistration() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            if self.receivedRealtimeSessionSnapshot {
                self.registerClientWhatsAppToolIfNeeded()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) { [weak self] in
            self?.registerClientWhatsAppToolIfNeeded()
        }
    }

    func registerClientWhatsAppToolIfNeeded() {
        guard let dc = dataChannel, dc.readyState == .open else { return }
        guard !didRegisterClientWhatsAppToolThisConnection else { return }
        let current = cachedRealtimeSessionTools
        if current.contains(where: { ($0["name"] as? String) == "send_whatsapp_message" }) {
            didRegisterClientWhatsAppToolThisConnection = true
            log("✅ send_whatsapp_message already on session (\(current.count) tools)")
            return
        }
        var merged = current
        merged.append(LimiRealtimeClientToolDefinitions.sendWhatsappMessage)
        let event: [String: Any] = [
            "type": "session.update",
            "session": ["tools": merged],
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: event),
              dc.sendData(RTCDataBuffer(data: data, isBinary: false)) else {
            log("❌ session.update (tools) failed to send")
            return
        }
        log("✅ session.update: appended send_whatsapp_message → \(merged.count) tools")
        didRegisterClientWhatsAppToolThisConnection = true
    }

    /// Parses a completed function call from OpenAI (e.g. control_light),
    /// publishes it for UI feedback, sends the tool output back via data channel,
    /// and forwards to the webhook.
    func handleFunctionCallDone(_ obj: [String: Any]) {
        let callId = obj["call_id"] as? String ?? UUID().uuidString
        let name = obj["name"] as? String ?? ""
        let argsString = obj["arguments"] as? String ?? "{}"

        log("🔧 Tool call: \(name) id=\(callId) args=\(argsString)")

        guard let argsData = argsString.data(using: .utf8),
              let args = try? JSONSerialization.jsonObject(with: argsData) as? [String: Any] else {
            log("❌ Failed to parse tool call arguments")
            sendToolOutput(callId: callId, output: "{\"error\": \"Failed to parse arguments\"}")
            return
        }

        // Personalize / onboarding: backend should register `personalize_set_field` with { "field": "name"|"use_case"|"goals", "value": "..." }
        let toolNameLower = name.lowercased()
        if toolNameLower == "personalize_set_field" || toolNameLower == "set_personalize_field" {
            handlePersonalizeSetFieldTool(callId: callId, args: args)
            return
        }
        // WhatsApp: tool is registered client-side (`session.update`) and/or on the server.
        if toolNameLower == "send_whatsapp_message" || toolNameLower == "whatsapp_send_message" {
            handleSendWhatsAppTool(callId: callId, args: args)
            return
        }

        let action = args["action"] as? String ?? "unknown"
        let mode = args["mode"] as? String
        let brightness = args["brightness"] as? Int
        let room = args["room"] as? String
        let userText = args["user_text"] as? String

        let toolCall = LimiToolCall(
            callId: callId,
            name: name,
            action: action,
            mode: mode,
            brightness: brightness,
            room: room,
            userText: userText
        )

        DispatchQueue.main.async { [weak self] in
            self?.lastToolCall = toolCall
        }

        postWebhook(event: "tool_call", payload: [
            "call_id": callId,
            "name": name,
            "action": action,
            "mode": mode ?? "",
            "brightness": brightness ?? -1,
            "room": room ?? "",
            "user_text": userText ?? ""
        ])

        let result: [String: Any] = [
            "status": "ok",
            "action": action,
            "room": room ?? "default",
            "executed": true
        ]
        if let resultData = try? JSONSerialization.data(withJSONObject: result),
           let resultString = String(data: resultData, encoding: .utf8) {
            sendToolOutput(callId: callId, output: resultString)
        }
    }

    private func handleSendWhatsAppTool(callId: String, args: [String: Any]) {
        let message = (args["message"] as? String)
            ?? (args["text"] as? String)
            ?? (args["body"] as? String)
            ?? ""
        let contactName = (args["contact_name"] as? String)
            ?? (args["recipient_name"] as? String)
            ?? (args["recipient"] as? String)
        let phone = (args["phone"] as? String)
            ?? (args["phone_e164"] as? String)
            ?? (args["phone_number"] as? String)

        let recipientLabel = [contactName, phone]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty } ?? "contact"

        WhatsAppContactMessenger.shared.openDraft(
            contactName: contactName,
            phoneDigitsOverride: phone,
            message: message
        ) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let detail):
                self.log("✅ WhatsApp tool: \(detail)")
                let toolCall = LimiToolCall(
                    callId: callId,
                    name: "send_whatsapp_message",
                    action: "whatsapp_draft",
                    mode: nil,
                    brightness: nil,
                    room: recipientLabel,
                    userText: message.trimmingCharacters(in: .whitespacesAndNewlines)
                )
                DispatchQueue.main.async {
                    self.lastToolCall = toolCall
                }
                self.postWebhook(event: "tool_call", payload: [
                    "call_id": callId,
                    "name": "send_whatsapp_message",
                    "action": "whatsapp_draft",
                    "recipient_hint": recipientLabel,
                    "ok": true,
                ])
                let payload: [String: Any] = [
                    "ok": true,
                    "opened_whatsapp": true,
                    "detail": detail,
                    "recipient_hint": recipientLabel,
                ]
                if let data = try? JSONSerialization.data(withJSONObject: payload),
                   let str = String(data: data, encoding: .utf8) {
                    self.sendToolOutput(callId: callId, output: str)
                }
            case .failure(let error):
                self.log("❌ WhatsApp tool: \(error.localizedDescription)")
                self.postWebhook(event: "tool_call", payload: [
                    "call_id": callId,
                    "name": "send_whatsapp_message",
                    "action": "whatsapp_draft",
                    "ok": false,
                    "error": error.localizedDescription,
                ])
                let payload: [String: Any] = [
                    "ok": false,
                    "error": error.localizedDescription,
                ]
                if let data = try? JSONSerialization.data(withJSONObject: payload),
                   let str = String(data: data, encoding: .utf8) {
                    self.sendToolOutput(callId: callId, output: str)
                }
            }
        }
    }

    private func handlePersonalizeSetFieldTool(callId: String, args: [String: Any]) {
        let field = (args["field"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let value = (args["value"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !field.isEmpty, !value.isEmpty else {
            if let errData = try? JSONSerialization.data(withJSONObject: ["ok": false, "error": "missing field or value"] as [String: Any]),
               let errStr = String(data: errData, encoding: .utf8) {
                sendToolOutput(callId: callId, output: errStr)
            }
            return
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .limiPersonalizeToolUpdate,
                object: nil,
                userInfo: ["field": field, "value": value]
            )
        }
        if let okData = try? JSONSerialization.data(withJSONObject: ["ok": true, "field": field, "applied": true] as [String: Any]),
           let okStr = String(data: okData, encoding: .utf8) {
            sendToolOutput(callId: callId, output: okStr)
        }
    }

    /// Sends tool call output back to OpenAI via the data channel so the model
    /// can incorporate the result into its response.
    func sendToolOutput(callId: String, output: String) {
        guard let dc = dataChannel, dc.readyState == .open else {
            log("⚠️ DataChannel not open — cannot send tool output for \(callId)")
            return
        }

        let itemCreate: [String: Any] = [
            "type": "conversation.item.create",
            "item": [
                "type": "function_call_output",
                "call_id": callId,
                "output": output
            ]
        ]

        if let data = try? JSONSerialization.data(withJSONObject: itemCreate),
           dc.sendData(RTCDataBuffer(data: data, isBinary: false)) {
            log("✅ Sent tool output for \(callId)")
        } else {
            log("❌ Failed to send tool output for \(callId)")
        }

        let responseCreate: [String: Any] = ["type": "response.create"]
        if let data = try? JSONSerialization.data(withJSONObject: responseCreate) {
            dc.sendData(RTCDataBuffer(data: data, isBinary: false))
            log("✅ Sent response.create after tool output")
        }
    }
}
