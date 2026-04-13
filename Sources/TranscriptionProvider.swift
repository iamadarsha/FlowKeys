import Foundation

enum TranscriptionProvider: String, CaseIterable, Codable, Identifiable {
    case groq = "groq"
    case openai = "openai"
    case gemini = "gemini"
    case grok = "grok"
    case claude = "claude"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .groq: return "Groq (fastest, free tier)"
        case .openai: return "OpenAI Whisper"
        case .gemini: return "Google Gemini"
        case .grok: return "xAI Grok"
        case .claude: return "Anthropic Claude"
        }
    }

    var shortName: String {
        switch self {
        case .groq:   return "Groq"
        case .openai: return "OpenAI"
        case .gemini: return "Gemini"
        case .grok:   return "Grok"
        case .claude: return "Claude"
        }
    }

    var shortDescription: String {
        switch self {
        case .groq:
            return "⚡ Fastest • Free tier available • Recommended for beginners"
        case .openai:
            return "🎯 Most accurate • Pay-per-use"
        case .gemini:
            return "🔷 Google • Generous free tier"
        case .grok:
            return "✕ xAI • Fast & capable"
        case .claude:
            return "🧠 Anthropic • Best post-processing quality"
        }
    }

    var transcriptionEndpoint: String {
        switch self {
        case .groq:
            return "https://api.groq.com/openai/v1/audio/transcriptions"
        case .openai:
            return "https://api.openai.com/v1/audio/transcriptions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        case .grok:
            return "https://api.x.ai/v1/audio/transcriptions"
        case .claude:
            // Claude is hybrid mode for this app: STT is delegated to Groq Whisper.
            return "https://api.groq.com/openai/v1/audio/transcriptions"
        }
    }

    var llmEndpoint: String {
        switch self {
        case .groq:
            return "https://api.groq.com/openai/v1/chat/completions"
        case .openai:
            return "https://api.openai.com/v1/chat/completions"
        case .gemini:
            return "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
        case .grok:
            return "https://api.x.ai/v1/chat/completions"
        case .claude:
            return "https://api.anthropic.com/v1/messages"
        }
    }

    var openAICompatibleBaseURL: String? {
        switch self {
        case .groq:
            return "https://api.groq.com/openai/v1"
        case .openai:
            return "https://api.openai.com/v1"
        case .grok:
            return "https://api.x.ai/v1"
        case .gemini, .claude:
            return nil
        }
    }

    var transcriptionModel: String {
        switch self {
        case .groq:
            return "whisper-large-v3-turbo"
        case .openai:
            return "whisper-1"
        case .gemini:
            return "gemini-2.5-flash"
        case .grok:
            return "whisper-1"
        case .claude:
            // Claude mode uses Groq STT and Claude for post-processing.
            return "whisper-large-v3-turbo"
        }
    }

    var llmModel: String {
        switch self {
        case .groq:
            return "openai/gpt-oss-20b"
        case .openai:
            return "gpt-4o-mini"
        case .gemini:
            return "gemini-2.5-flash"
        case .grok:
            return "grok-2-latest"
        case .claude:
            return "claude-3-5-haiku-latest"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .groq:
            return "gsk_..."
        case .openai:
            return "sk-..."
        case .gemini:
            return "AIza..."
        case .grok:
            return "xai-..."
        case .claude:
            return "sk-ant-..."
        }
    }

    var apiKeyURL: String {
        switch self {
        case .groq:
            return "https://console.groq.com/keys"
        case .openai:
            return "https://platform.openai.com/api-keys"
        case .gemini:
            return "https://aistudio.google.com/app/apikey"
        case .grok:
            return "https://console.x.ai"
        case .claude:
            return "https://console.anthropic.com/settings/keys"
        }
    }

    var defaultPostProcessingModel: String {
        llmModel
    }

    var supportsOpenAIChatPayload: Bool {
        switch self {
        case .groq, .openai, .grok:
            return true
        case .gemini, .claude:
            return false
        }
    }

    func keyLikelyValidFormat(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        switch self {
        case .groq:
            return trimmed.hasPrefix("gsk_")
        case .openai:
            return trimmed.hasPrefix("sk-")
        case .gemini:
            return trimmed.hasPrefix("AIza")
        case .grok:
            return trimmed.hasPrefix("xai-") || trimmed.hasPrefix("sk-")
        case .claude:
            return trimmed.hasPrefix("sk-ant-")
        }
    }
}
