import AVFoundation
import Foundation
import os.log

private let transcriptionLog = OSLog(subsystem: "com.flowkeys.app", category: "Transcription")

final class TranscriptionService {
    private let provider: TranscriptionProvider
    private let keyStore: APIKeyStore
    private let forceHTTP2: Bool
    private let languageMode: UserLanguageMode
    private let timeoutSeconds: TimeInterval = 30
    private let maxAttempts = 2 // first attempt + one retry
    private let uploadSampleRate = 16_000.0
    private let uploadChannelCount: AVAudioChannelCount = 1

    /// Minimum recording duration (seconds) below which Whisper hallucinates.
    private let minimumAudioDuration: TimeInterval = 0.5
    /// Minimum peak RMS — below this the mic captured nothing useful.
    private let minimumPeakRMS: Float = 0.002

    init(provider: TranscriptionProvider, keyStore: APIKeyStore, forceHTTP2: Bool = false, languageMode: UserLanguageMode = .pureEnglish) {
        self.provider = provider
        self.keyStore = keyStore
        self.forceHTTP2 = forceHTTP2
        self.languageMode = languageMode
    }

    static func validateAPIKey(_ key: String, for provider: TranscriptionProvider) async -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        switch provider {
        case .gemini:
            guard var components = URLComponents(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
                return false
            }
            components.queryItems = [URLQueryItem(name: "key", value: trimmed)]
            guard let url = components.url else { return false }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                return (response as? HTTPURLResponse)?.statusCode == 200
            } catch {
                return false
            }

        case .claude:
            guard let url = URL(string: "https://api.anthropic.com/v1/models") else { return false }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue(trimmed, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                return (response as? HTTPURLResponse)?.statusCode == 200
            } catch {
                return false
            }

        case .groq, .openai, .grok:
            guard let baseURL = provider.openAICompatibleBaseURL,
                  let url = URL(string: "\(baseURL)/models") else {
                return false
            }
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                return (response as? HTTPURLResponse)?.statusCode == 200
            } catch {
                return false
            }
        }
    }

    func transcribe(fileURL: URL) async throws -> String {
        let prepared = try prepareAudioForUpload(from: fileURL)
        defer { prepared.cleanup() }

        try validateAudioForTranscription(fileURL: prepared.fileURL)

        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                let result = try await withTimeout(seconds: timeoutSeconds) {
                    switch self.provider {
                    case .gemini:
                        return try await self.transcribeWithGemini(fileURL: prepared.fileURL)
                    case .groq, .openai, .grok, .claude:
                        return try await self.transcribeWithOpenAICompatible(fileURL: prepared.fileURL)
                    }
                }
                let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else {
                    throw TranscriptionError.transcriptionFailed("Transcription returned empty text")
                }
                return trimmed
            } catch {
                lastError = error
                let isLastAttempt = attempt == maxAttempts
                if !isLastAttempt {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        }

        if let lastError {
            throw lastError
        }
        throw TranscriptionError.transcriptionFailed("Unknown transcription failure")
    }

    // MARK: - Audio validation

    /// Throws `TranscriptionError.transcriptionFailed` if the audio is too short
    /// or too quiet to produce a real transcript. This prevents Whisper from
    /// hallucinating phrases like "Thank you" on silent / near-silent input.
    private func validateAudioForTranscription(fileURL: URL) throws {
        guard let audioFile = try? AVAudioFile(forReading: fileURL) else { return }

        let sampleRate = audioFile.fileFormat.sampleRate
        guard sampleRate > 0 else { return }

        let durationSeconds = Double(audioFile.length) / sampleRate
        guard durationSeconds >= minimumAudioDuration else {
            os_log(.info, log: transcriptionLog,
                   "Audio too short (%.2fs < %.2fs) — skipping transcription",
                   durationSeconds, minimumAudioDuration)
            throw TranscriptionError.transcriptionFailed("Recording too short — hold the shortcut for at least half a second while speaking.")
        }

        // Read up to the first 2 seconds to check for meaningful audio energy.
        let framesToCheck = AVAudioFrameCount(min(Double(audioFile.length), sampleRate * 2.0))
        guard framesToCheck > 0,
              let format = AVAudioFormat(
                commonFormat: audioFile.fileFormat.commonFormat,
                sampleRate: sampleRate,
                channels: audioFile.fileFormat.channelCount,
                interleaved: audioFile.fileFormat.isInterleaved
              ),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToCheck),
              (try? audioFile.read(into: buffer, frameCount: framesToCheck)) != nil,
              buffer.frameLength > 0 else {
            return
        }

        var peakRMS: Float = 0
        let frames = Int(buffer.frameLength)

        if let floatData = buffer.floatChannelData {
            var sumSq: Float = 0
            let samples = floatData[0]
            for i in 0..<frames { sumSq += samples[i] * samples[i] }
            peakRMS = sqrtf(sumSq / Float(frames))
        } else if let int16Data = buffer.int16ChannelData {
            var sumSq: Float = 0
            let samples = int16Data[0]
            for i in 0..<frames {
                let s = Float(samples[i]) / Float(Int16.max)
                sumSq += s * s
            }
            peakRMS = sqrtf(sumSq / Float(frames))
        }

        os_log(.info, log: transcriptionLog, "Audio validation — duration=%.2fs rms=%.5f", durationSeconds, peakRMS)

        guard peakRMS >= minimumPeakRMS else {
            throw TranscriptionError.transcriptionFailed("No speech detected — check that your microphone is working and not muted.")
        }
    }

    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TranscriptionError.transcriptionTimedOut(seconds)
            }

            guard let firstResult = try await group.next() else {
                throw TranscriptionError.transcriptionFailed("No transcription result")
            }
            group.cancelAll()
            return firstResult
        }
    }

    private func transcribeWithOpenAICompatible(fileURL: URL) async throws -> String {
        let (effectiveProvider, apiKey) = try effectiveOpenAICompatibleProviderAndKey()

        guard let endpointURL = URL(string: effectiveProvider.transcriptionEndpoint) else {
            throw TranscriptionError.submissionFailed("Invalid transcription endpoint URL")
        }

        if forceHTTP2 {
            return try await transcribeWithCurlHTTP2(fileURL: fileURL, endpointURL: endpointURL, apiKey: apiKey, model: effectiveProvider.transcriptionModel)
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let audioData = try Data(contentsOf: fileURL)
        let body = makeMultipartBody(
            audioData: audioData,
            fileName: fileURL.lastPathComponent,
            model: effectiveProvider.transcriptionModel,
            boundary: boundary
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.upload(for: request, from: body)
        } catch {
            throw TranscriptionError.submissionFailed("Network error while uploading audio")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.submissionFailed("No response from transcription server")
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseHTTPErrorMessage(data: data)
            throw TranscriptionError.submissionFailed(message)
        }

        return try parseOpenAITranscript(from: data)
    }

    private func transcribeWithCurlHTTP2(
        fileURL: URL,
        endpointURL: URL,
        apiKey: String,
        model: String
    ) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
            var curlArgs = [
                "--silent",
                "--show-error",
                "--fail",
                "--http2",
                "--max-time", String(Int(self.timeoutSeconds)),
                endpointURL.absoluteString,
                "-H", "Authorization: Bearer \(apiKey)",
                "-F", "model=\(model)",
                "-F", "language=\(self.languageMode.whisperLanguageCode)",
                "-F", "file=@\(fileURL.path);type=\(self.audioContentType(for: fileURL.lastPathComponent))"
            ]
            // Add the Indian Whisper primer for non-English language modes
            if self.languageMode != .pureEnglish {
                curlArgs.insert(contentsOf: ["-F", "prompt=\(INDIAN_WHISPER_PRIMER)"], at: curlArgs.count - 2)
            }
            process.arguments = curlArgs

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                throw TranscriptionError.submissionFailed("Unable to launch curl for HTTP/2 transport")
            }

            let outputData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
            let errorText = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            guard process.terminationStatus == 0 else {
                let suffix = errorText.isEmpty ? "" : ": \(errorText)"
                throw TranscriptionError.submissionFailed("HTTP/2 upload failed\(suffix)")
            }

            return try self.parseOpenAITranscript(from: outputData)
        }.value
    }

    private func transcribeWithGemini(fileURL: URL) async throws -> String {
        guard let apiKey = keyStore.getKey(for: .gemini) else {
            throw TranscriptionError.missingAPIKey("Google Gemini API key is missing")
        }

        guard var components = URLComponents(string: TranscriptionProvider.gemini.transcriptionEndpoint) else {
            throw TranscriptionError.submissionFailed("Invalid Gemini endpoint URL")
        }
        components.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let endpointURL = components.url else {
            throw TranscriptionError.submissionFailed("Invalid Gemini endpoint URL")
        }

        let audioData = try Data(contentsOf: fileURL)
        let base64Audio = audioData.base64EncodedString()

        let payload: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": transcriptionPromptForGemini()],
                    [
                        "inlineData": [
                            "mimeType": "audio/wav",
                            "data": base64Audio
                        ]
                    ]
                ]
            ]],
            "generationConfig": [
                "temperature": 0.0
            ]
        ]

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = timeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranscriptionError.submissionFailed("Network error while sending audio to Gemini")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.submissionFailed("No response from Gemini")
        }

        guard httpResponse.statusCode == 200 else {
            let message = parseHTTPErrorMessage(data: data)
            throw TranscriptionError.submissionFailed(message)
        }

        return try parseGeminiTranscript(from: data)
    }

    private func effectiveOpenAICompatibleProviderAndKey() throws -> (TranscriptionProvider, String) {
        switch provider {
        case .claude:
            // Hybrid mode requirement: Claude is used for post-processing while STT is done via Groq Whisper.
            guard let groqKey = keyStore.getKey(for: .groq) else {
                throw TranscriptionError.missingAPIKey("Claude mode requires a Groq key for transcription. Add a Groq key in Settings.")
            }
            return (.groq, groqKey)

        case .groq, .openai, .grok:
            guard let key = keyStore.getKey(for: provider) else {
                throw TranscriptionError.missingAPIKey("\(provider.displayName) API key is missing")
            }
            return (provider, key)

        case .gemini:
            throw TranscriptionError.submissionFailed("Gemini uses a separate transcription transport")
        }
    }

    private func parseOpenAITranscript(from data: Data) throws -> String {
        if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }

        let plainText = String(data: data, encoding: .utf8) ?? ""
        let text = plainText
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw TranscriptionError.transcriptionFailed("Invalid transcription response")
        }

        return text
    }

    private func parseGeminiTranscript(from data: Data) throws -> String {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]] else {
            throw TranscriptionError.transcriptionFailed("Invalid Gemini transcription response")
        }

        let combined = parts.compactMap { $0["text"] as? String }.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !combined.isEmpty else {
            throw TranscriptionError.transcriptionFailed("Gemini returned empty transcript")
        }
        return combined
    }

    private func parseHTTPErrorMessage(data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let errorObj = json["error"] as? [String: Any],
           let message = errorObj["message"] as? String,
           !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return message
        }

        let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return raw.isEmpty ? "Request failed" : raw
    }

    private func makeMultipartBody(audioData: Data, fileName: String, model: String, boundary: String) -> Data {
        var body = Data()

        func append(_ value: String) {
            body.append(Data(value.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        append("\(model)\r\n")

        // Inject language code for Whisper when a non-English language mode is active.
        // Research source: Biswas et al. Interspeech 2025 — <|hi|> language
        // token outperforms <|en|> for Hindi-English code-mix scenarios.
        let langCode = languageMode.whisperLanguageCode
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"language\"\r\n\r\n")
        append("\(langCode)\r\n")

        // Inject the Indian Whisper primer as a prompt to seed Whisper's vocabulary
        // decoder with common Hinglish patterns and Indian names.
        if languageMode != .pureEnglish {
            append("--\(boundary)\r\n")
            append("Content-Disposition: form-data; name=\"prompt\"\r\n\r\n")
            append("\(INDIAN_WHISPER_PRIMER)\r\n")
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n")
        append("Content-Type: \(audioContentType(for: fileName))\r\n\r\n")
        body.append(audioData)
        append("\r\n")
        append("--\(boundary)--\r\n")

        return body
    }

    private func prepareAudioForUpload(from fileURL: URL) throws -> PreparedUploadAudio {
        let inputFile = try AVAudioFile(forReading: fileURL)
        if isPreferredUploadFormat(file: inputFile, fileURL: fileURL) {
            return PreparedUploadAudio(fileURL: fileURL, deleteOnCleanup: false)
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")

        do {
            try AudioNormalization.writePreferredAudioCopy(from: fileURL, to: outputURL)
        } catch {
            throw TranscriptionError.audioPreparationFailed(error.localizedDescription)
        }

        return PreparedUploadAudio(fileURL: outputURL, deleteOnCleanup: true)
    }

    private func isPreferredUploadFormat(file: AVAudioFile, fileURL: URL) -> Bool {
        let format = file.fileFormat
        return fileURL.pathExtension.lowercased() == "wav"
            && abs(format.sampleRate - uploadSampleRate) < 0.5
            && format.channelCount == uploadChannelCount
            && format.commonFormat == .pcmFormatInt16
    }

    private func audioContentType(for fileName: String) -> String {
        let lowered = fileName.lowercased()
        if lowered.hasSuffix(".wav") { return "audio/wav" }
        if lowered.hasSuffix(".mp3") { return "audio/mpeg" }
        if lowered.hasSuffix(".m4a") { return "audio/mp4" }
        return "application/octet-stream"
    }

    /// Constructs the Gemini transcription prompt, including the Indian Whisper primer
    /// when the user's language mode indicates Hindi or Hinglish.
    private func transcriptionPromptForGemini() -> String {
        var prompt = "Transcribe this audio exactly. Return only the transcript text."
        if languageMode != .pureEnglish {
            prompt += "\n\nThe speaker is likely using Hindi, English, or Hinglish (code-switched Hindi-English). Preserve all code-switching exactly as spoken. Use Roman script for Hinglish and Devanagari only if the speaker clearly uses Hindi throughout.\n\n" + INDIAN_WHISPER_PRIMER
        }
        return prompt
    }
}

enum TranscriptionError: LocalizedError {
    case missingAPIKey(String)
    case submissionFailed(String)
    case transcriptionFailed(String)
    case transcriptionTimedOut(TimeInterval)
    case audioPreparationFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey(let msg):
            return msg
        case .submissionFailed(let msg):
            return "Transcription request failed: \(msg)"
        case .transcriptionFailed(let msg):
            return "Transcription failed: \(msg)"
        case .transcriptionTimedOut(let seconds):
            return "Transcription timed out after \(Int(seconds)) seconds"
        case .audioPreparationFailed(let msg):
            return "Audio preparation failed: \(msg)"
        }
    }
}

private struct PreparedUploadAudio {
    let fileURL: URL
    let deleteOnCleanup: Bool

    func cleanup() {
        guard deleteOnCleanup else { return }
        try? FileManager.default.removeItem(at: fileURL)
    }
}
