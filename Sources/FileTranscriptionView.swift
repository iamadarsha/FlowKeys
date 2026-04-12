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
                Image(systemName: "waveform.and.person.filled")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(nsColor: .controlAccentColor))
                Text("File Transcription")
                    .font(.title)
                    .fontWeight(.semibold)
                Text("Process existing audio or video files.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 20)
            
            // File Selection
            VStack(spacing: 12) {
                if let url = selectedFileURL {
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.blue)
                        Text(url.lastPathComponent)
                            .font(.headline)
                        Spacer()
                        Button(action: { selectedFileURL = nil }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)
                } else {
                    Button(action: selectFile) {
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.up.doc")
                                .font(.system(size: 30))
                            Text("Select Audio/Video File")
                                .font(.headline)
                            Text("MP3, M4A, WAV, MP4, MOV")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 30)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.secondary.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6]))
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
                        .foregroundStyle(.secondary)
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
                            .foregroundStyle(.secondary)
                    }
                } else if !transcriptResult.isEmpty {
                    ScrollView {
                        Text(transcriptResult)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                    }
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(8)
                    .frame(maxHeight: 200)
                    
                    HStack {
                        Button("Copy to Clipboard") {
                            let pb = NSPasteboard.general
                            pb.clearContents()
                            pb.setString(transcriptResult, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear") {
                            transcriptResult = ""
                            selectedFileURL = nil
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Button("Transcribe File") {
                    Task { await transcribeSelectedFile() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(selectedFileURL == nil || isTranscribing)
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .frame(width: 480)
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
