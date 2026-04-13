import SwiftUI
import UniformTypeIdentifiers

struct FileTranscriptionView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedFileURL: URL?
    @State private var isTranscribing = false
    @State private var progressText = ""
    @State private var transcriptResult = ""
    @State private var useSmartModes = true
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(KM.accent.opacity(0.15))
                        .frame(width: 60, height: 60)
                    Image(systemName: "waveform.and.person.filled")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(LinearGradient(colors: [KM.accent, KM.salmon], startPoint: .topLeading, endPoint: .bottomTrailing))
                }
                Text("File Transcription")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(KM.onSurface)
                Text("Process existing audio or video files.")
                    .font(.system(size: 12))
                    .foregroundColor(KM.muted)
            }
            .padding(.top, 20)

            // File Selection
            VStack(spacing: 12) {
                if let url = selectedFileURL {
                    HStack(spacing: 10) {
                        ZStack {
                            Circle().fill(KM.accent.opacity(0.15)).frame(width: 32, height: 32)
                            Image(systemName: "doc.fill")
                                .font(.system(size: 14))
                                .foregroundColor(KM.accent)
                        }
                        Text(url.lastPathComponent)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(KM.onSurface)
                        Spacer()
                        Button(action: { selectedFileURL = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(KM.muted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(12)
                    .background(KM.surfaceHi)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KM.outline, lineWidth: 1))
                } else {
                    Button(action: selectFile) {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundColor(KM.muted)
                            Text("Select Audio/Video File")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(KM.onSurface.opacity(0.7))
                            Text("MP3, M4A, WAV, MP4, MOV")
                                .font(.system(size: 11))
                                .foregroundColor(KM.muted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(KM.surfaceHi)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(KM.muted.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal)
            
            // Options
            Toggle(isOn: $useSmartModes) {
                VStack(alignment: .leading) {
                    Text("Apply Smart Formatting")
                    Text("Expands snippets, learns vocabulary, and applies the active dictation mode.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            
            // Action & Status
            VStack(spacing: 12) {
                if isTranscribing {
                    HStack(spacing: 12) {
                        ProgressView()
                            .controlSize(.small)
                        Text(progressText)
                            .font(.subheadline)
                            .foregroundColor(KM.muted)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                } else if !transcriptResult.isEmpty {
                    ScrollView {
                        Text(transcriptResult)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(KM.onSurface)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(KM.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(KM.outline, lineWidth: 1))
                    .frame(maxHeight: 200)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    
                    HStack(spacing: 8) {
                        Button("Copy to Clipboard") {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(transcriptResult, forType: .string)
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KM.accent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(KM.accent.opacity(0.12))
                        .clipShape(Capsule())
                        .buttonStyle(.plain)

                        Button("Clear") {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                transcriptResult = ""
                                selectedFileURL = nil
                            }
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(KM.muted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(KM.surfaceHi)
                        .clipShape(Capsule())
                        .buttonStyle(.plain)
                    }
                    .transition(.opacity)
                }
                
                Button {
                    Task { await transcribeSelectedFile() }
                } label: {
                    HStack(spacing: 8) {
                        if isTranscribing {
                            ProgressView().controlSize(.small).tint(.white)
                                .transition(.opacity)
                        } else {
                            Image(systemName: "waveform")
                                .font(.system(size: 13, weight: .semibold))
                                .transition(.opacity)
                        }
                        Text(isTranscribing ? "Transcribing…" : "Transcribe File")
                            .font(.system(size: 13, weight: .semibold))
                            .animation(.easeOut(duration: 0.18), value: isTranscribing)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Group {
                        if selectedFileURL == nil || isTranscribing {
                            KM.surfaceHi
                        } else {
                            LinearGradient(colors: [KM.accent, KM.accent.opacity(0.8)], startPoint: .leading, endPoint: .trailing)
                        }
                    })
                    .animation(.spring(response: 0.28, dampingFraction: 0.8), value: isTranscribing)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(selectedFileURL == nil || isTranscribing)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: isTranscribing)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: transcriptResult.isEmpty)
        }
        .frame(width: 480)
        .background(KM.bg)
    }
    
    private func selectFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [
            .audio,
            .audiovisualContent,
            .mpeg4Movie,
            .quickTimeMovie,
            .mp3,
            .wav,
            .mpeg4Audio
        ]
        
        if panel.runModal() == .OK, let url = panel.url {
            selectedFileURL = url
            transcriptResult = ""
        }
    }
    
    @MainActor
    private func transcribeSelectedFile() async {
        guard let url = selectedFileURL else { return }
        
        isTranscribing = true
        progressText = "Extracting audio and uploading..."
        transcriptResult = ""
        
        do {
            let service = TranscriptionService(
                provider: appState.activeTranscriptionProvider,
                keyStore: APIKeyStore(),
                languageMode: appState.languageMode
            )
            
            // Step 1: Whisper Transcription
            let rawText = try await service.transcribe(fileURL: url)
            
            if !useSmartModes {
                transcriptResult = rawText
                isTranscribing = false
                return
            }
            
            // Step 2: Post-processing (Snippets + LLM + Dictionary)
            progressText = "Applying Smart Modes and Post-processing..."
            
            let context = AppContext(
                appName: "File Transcription",
                bundleIdentifier: nil,
                windowTitle: url.lastPathComponent,
                selectedText: nil,
                currentActivity: "Transcribing a pre-recorded file.",
                contextPrompt: nil,
                screenshotDataURL: nil,
                screenshotMimeType: nil,
                screenshotError: nil
            )
            
            let ppService = PostProcessingService(
                provider: appState.activeLLMProvider,
                keyStore: APIKeyStore(),
                languageMode: appState.languageMode
            )
            
            let (finalText, _, _) = await appState.processTranscript(
                rawText,
                context: context,
                postProcessingService: ppService,
                customVocabulary: appState.customVocabulary,
                customSystemPrompt: appState.customSystemPrompt
            )
            
            transcriptResult = finalText
            isTranscribing = false
            
        } catch {
            isTranscribing = false
            transcriptResult = "Error: \(error.localizedDescription)"
        }
    }
}
