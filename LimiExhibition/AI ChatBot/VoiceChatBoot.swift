//
//  VoiceChatBot.swift
//  Limi
//
//  Created by Shahrukh Ahmed on 17/12/2025.
//

import SwiftUI
import AVFoundation

struct VoiceChatBot: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showGooglePermissionAlert = false
    @State private var isRequestingGooglePermissions = false
    @StateObject private var googleAuthManager = GoogleAuthManager()
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 40) {
                Button(action: {
                    print("[PrivacyPolicyView] Grant Google Permissions button tapped")
                    showGooglePermissionAlert = true
                }) {
                    Text("Grant Google Permissions")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .disabled(isRequestingGooglePermissions)
                .alert("Google Permissions", isPresented: $showGooglePermissionAlert) {
                    Button("Cancel", role: .cancel) {
                        print("[PrivacyPolicyView] Google permissions alert canceled by user")
                    }
                    Button(isRequestingGooglePermissions ? "Requesting..." : "Allow") {
                        print("[PrivacyPolicyView] Allow button tapped in Google permissions alert")
                        guard !isRequestingGooglePermissions else { return }
                        print("[PrivacyPolicyView] Starting Google permissions request...")
                        isRequestingGooglePermissions = true
                        let scopes = [
                            "https://www.googleapis.com/auth/calendar",
                            "https://www.googleapis.com/auth/gmail.send",
                            "https://www.googleapis.com/auth/gmail.readonly",
                            "https://www.googleapis.com/auth/contacts.readonly"
                        ]
                        print("[PrivacyPolicyView] Requesting Google permissions with scopes: \(scopes)")
                        googleAuthManager.requestGooglePermissions(scopes: scopes) { success in
                            print("[PrivacyPolicyView] Google permissions request completed. Success = \(success)")
                            DispatchQueue.main.async {
                                isRequestingGooglePermissions = false
                                print("[PrivacyPolicyView] isRequestingGooglePermissions set to false")
                            }
                        }
                    }
                } message: {
                    Text("This app will request access to your Google Calendar, Gmail (read/send), and Contacts to provide related features. You can change these permissions at any time in your Google Account settings.")
                }
                if audioManager.isProcessing {
                    
                    FirstOrbView(
                        hue: 0.6,
                        hoverIntensity: 0.5,
                        rotateOnHover: true,
                        forceHoverState: true
                    )
                    .frame(height: 400)
                    
                    Text("Processing...")
                        .font(.headline)
                        .foregroundColor(.white)
                } else {
                    FirstOrbView(
                        hue: 0.3,
                        hoverIntensity: 0.2,
                        rotateOnHover: false,
                        forceHoverState: false
                    )
                    .frame(height: 400)
                    
                    Text(audioManager.isRecording ? "Recording..." : "Tap to speak")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                Button(action: {
                    if audioManager.isRecording {
                        audioManager.stopRecording()
                    } else {
                        audioManager.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(audioManager.isRecording ? Color.red : Color.blue)
                            .frame(width: 80, height: 80)
                            .shadow(color: audioManager.isRecording ? .red.opacity(0.5) : .blue.opacity(0.5), radius: 20)
                        
                        Image(systemName: audioManager.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .disabled(audioManager.isProcessing)
                
                if let error = audioManager.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding()
                }
                
                if let response = audioManager.apiResponse {
                    ScrollView {
                        Text(response)
                            .font(.body)
                            .foregroundColor(.white)
                            .padding()
                    }
                    .frame(maxHeight: 200)
                }
            }
            .padding()
        }
    }
}

class AudioManager: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isProcessing = false
    @Published var errorMessage: String?
    @Published var apiResponse: String?
    
    private var audioRecorder: AVAudioRecorder?
    private var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    private let apiURL = "https://dev.api.limitless-lighting.co.uk/limi-ai/transcribe-audio"
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    override init() {
        super.init()
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try audioSession.setActive(true)
            
            audioSession.requestRecordPermission { [weak self] allowed in
                DispatchQueue.main.async {
                    if !allowed {
                        self?.errorMessage = "Microphone permission denied"
                    }
                }
            }
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
        }
    }
    
    func startRecording() {
        errorMessage = nil
        apiResponse = nil
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        
        let audioFilename = getDocumentsDirectory().appendingPathComponent("recording.m4a")
        convertToMP3AndUpload(audioURL: audioFilename)
    }
    
    private func convertToMP3AndUpload(audioURL: URL) {
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let audioData = try Data(contentsOf: audioURL)
                self.uploadAudioToAPI(audioData: audioData, filename: "recording.m4a")
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to read audio file: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func uploadAudioToAPI(audioData: Data, filename: String) {
        guard let url = URL(string: apiURL) else {
            DispatchQueue.main.async {
                self.errorMessage = "Invalid API URL"
                self.isProcessing = false
            }
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let token = AuthManager.shared.getToken(), !token.isEmpty {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"mp3_file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
                
                if let error = error {
                    self?.errorMessage = "Network error: \(error.localizedDescription)"
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self?.errorMessage = "Invalid response from server"
                    return
                }
                
                if httpResponse.statusCode == 200 {
                    if let data = data {
                        do {
                            struct LimiAIResponse: Decodable {
                                let success: Bool
                                let text: String?
                            }
                            let decoded = try JSONDecoder().decode(LimiAIResponse.self, from: data)
                            if let text = decoded.text, !text.isEmpty {
                                self?.apiResponse = text
                                self?.speak(text: text)
                            } else if let fallback = String(data: data, encoding: .utf8) {
                                self?.apiResponse = fallback
                            } else {
                                self?.apiResponse = "Success! Status code: \(httpResponse.statusCode)"
                            }
                        } catch {
                            if let responseString = String(data: data, encoding: .utf8) {
                                self?.apiResponse = responseString
                            } else {
                                self?.apiResponse = "Success! Status code: \(httpResponse.statusCode)"
                            }
                        }
                    } else {
                        self?.apiResponse = "Success! Status code: \(httpResponse.statusCode)"
                    }
                } else {
                    if let data = data, let errorString = String(data: data, encoding: .utf8) {
                        self?.errorMessage = "Server error (\(httpResponse.statusCode)): \(errorString)"
                    } else {
                        self?.errorMessage = "Server error: \(httpResponse.statusCode)"
                    }
                }
            }
        }
        
        task.resume()
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func speak(text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        speechSynthesizer.speak(utterance)
    }
}

#Preview {
    VoiceChatBot()
}
