import Foundation
import Speech
import AVFoundation
import Combine

@MainActor
final class VoiceManager: ObservableObject {
    @Published var isListening = false
    @Published var recognizedText = ""
    @Published var errorMessage: String?
    @Published var permissionGranted = false
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.checkMicrophonePermission()
                case .denied, .restricted, .notDetermined:
                    self?.permissionGranted = false
                    self?.errorMessage = "Speech recognition permission denied."
                @unknown default:
                    self?.permissionGranted = false
                }
            }
        }
    }
    
    private func checkMicrophonePermission() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.permissionGranted = true
                } else {
                    self?.permissionGranted = false
                    self?.errorMessage = "Microphone permission denied."
                }
            }
        }
    }
    
    func startListening() {
        guard permissionGranted, let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            errorMessage = "Speech recognizer is not available or permissions missing."
            return
        }
        
        do {
            try startRecording()
            isListening = true
            recognizedText = ""
            errorMessage = nil
            print("🎤 VoiceManager: Started listening...")
        } catch {
            errorMessage = "Failed to start recording: \(error.localizedDescription)"
            print("❌ VoiceManager error:", errorMessage ?? "")
        }
    }
    
    func stopListening() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest?.endAudio()
            isListening = false
            print("🎤 VoiceManager: Stopped listening. Final text: \(recognizedText)")
        }
    }
    
    private func startRecording() throws {
        // Cancel the previous task if it's running
        recognitionTask?.cancel()
        self.recognitionTask = nil
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw NSError(domain: "VoiceManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to create request"])
        }
        
        // Report partial results to update UI in real-time
        recognitionRequest.shouldReportPartialResults = true
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }
        
        audioEngine.prepare()
        try audioEngine.start()
        
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            if let result = result {
                DispatchQueue.main.async {
                    self.recognizedText = result.bestTranscription.formattedString
                }
            }
            
            if let error = error {
                print("❌ Speech error:", error.localizedDescription)
                self.stopListening()
            }
        }
    }
}
