import SwiftUI

struct VoiceTripLogView: View {
    
    let trip: TripMap
    @Environment(\.dismiss) private var dismiss
    @StateObject private var speech = SpeechRecognizer()
    @StateObject private var vm: VoiceTripLogViewModel
    
    @State private var hasPermission = false
    @State private var permissionChecked = false
    @State private var pulseScale: CGFloat = 1.0
    
    init(trip: TripMap) {
        self.trip = trip
        _vm = StateObject(wrappedValue: VoiceTripLogViewModel(trip: trip))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - Microphone Button
                    microphoneSection
                    
                    // MARK: - Live Transcript
                    if !speech.transcript.isEmpty {
                        transcriptSection
                    }
                    
                    // MARK: - Parsed Fields
                    if hasAnyParsedData {
                        parsedFieldsSection
                    }
                    
                    // MARK: - Hints
                    if speech.transcript.isEmpty && !speech.isRecording {
                        hintsSection
                    }
                    
                    // MARK: - Error
                    if let error = speech.errorMessage ?? vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 24)
            }
            .background(AppTheme.pageBackground)
            .navigationTitle("Voice Trip Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await vm.saveLog() }
                    }
                    .fontWeight(.semibold)
                    .disabled(!hasAnyParsedData || vm.isSaving)
                }
            }
            .alert("Log Saved ✓", isPresented: $vm.saveSuccess) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your voice trip log has been saved successfully.")
            }
            .task {
                hasPermission = await speech.requestPermissions()
                permissionChecked = true
            }
            .onChange(of: speech.transcript) { _, newValue in
                vm.parseTranscript(newValue)
            }
        }
    }
    
    // MARK: - Microphone Section
    private var microphoneSection: some View {
        VStack(spacing: 16) {
            ZStack {
                // Pulse rings when recording
                if speech.isRecording {
                    Circle()
                        .fill(AppTheme.primaryGreen.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulseScale)
                    
                    Circle()
                        .fill(AppTheme.primaryGreen.opacity(0.05))
                        .frame(width: 180, height: 180)
                        .scaleEffect(pulseScale)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulseScale)
                }
                
                Button {
                    toggleRecording()
                } label: {
                    ZStack {
                        Circle()
                            .fill(speech.isRecording ? AppTheme.statusDanger : AppTheme.primaryGreen)
                            .frame(width: 100, height: 100)
                            .shadow(color: (speech.isRecording ? AppTheme.statusDanger : AppTheme.primaryGreen).opacity(0.4), radius: 16, y: 4)
                        
                        Image(systemName: speech.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .disabled(!hasPermission && permissionChecked)
            }
            .onAppear { pulseScale = 1.15 }
            
            Text(speech.isRecording ? "Listening... Tap to stop" : "Tap to start speaking")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(speech.isRecording ? AppTheme.statusDanger : .secondary)
            
            if !hasPermission && permissionChecked {
                Text("Microphone & Speech permissions required. Please enable in Settings.")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }
    
    // MARK: - Transcript Section
    private var transcriptSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Transcript", systemImage: "text.quote")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            Text(speech.transcript)
                .font(.body)
                .foregroundStyle(.primary)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(.horizontal)
    }
    
    // MARK: - Parsed Fields Section
    private var parsedFieldsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Parsed Details", systemImage: "text.magnifyingglass")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            VStack(spacing: 0) {
                editableField(icon: "clock", label: "Start Time", text: $vm.startTime, placeholder: "e.g. 9:30 AM")
                Divider().padding(.leading, 52)
                editableField(icon: "clock.badge.checkmark", label: "End Time", text: $vm.endTime, placeholder: "e.g. 5:00 PM")
                Divider().padding(.leading, 52)
                editableField(icon: "mappin.and.ellipse", label: "Location", text: $vm.location, placeholder: "e.g. Mysore")
                Divider().padding(.leading, 52)
                editableField(icon: "gauge.with.dots.needle.33percent", label: "Mileage", text: $vm.mileage, placeholder: "e.g. 45230")
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal)
            
            Text("You can edit any field before saving.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.horizontal)
        }
    }
    
    // MARK: - Hints Section
    private var hintsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Try saying", systemImage: "lightbulb.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            
            VStack(alignment: .leading, spacing: 8) {
                hintBubble("\"Started at 9:30 AM from Mysore\"")
                hintBubble("\"Ended at 5 PM, mileage 45230 km\"")
                hintBubble("\"Location Bangalore, odometer reading 12500\"")
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helpers
    
    private func editableField(icon: String, label: String, text: Binding<String>, placeholder: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(AppTheme.primaryGreen)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: text)
                    .font(.body)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    private func hintBubble(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(AppTheme.mintGreen.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
    
    private var hasAnyParsedData: Bool {
        !vm.startTime.isEmpty || !vm.endTime.isEmpty || !vm.location.isEmpty || !vm.mileage.isEmpty
    }
    
    private func toggleRecording() {
        if speech.isRecording {
            speech.stopTranscribing()
        } else {
            speech.startTranscribing()
        }
    }
}
