// ============================================================
// FILE: Sources/LocalAI/SpeechAnalysis.swift
// FlowKeys — Local AI (Phase 3)
//
// Deterministic, model-free speech cleanup that runs BEFORE any LLM:
//   - filler removal (English + Hindi/Hinglish + conservative Bengali)
//   - self-correction detection (events only — the LLM does the collapse)
//   - pause analysis from VAD / segment timings → sentence-break hints
//   - whitespace / duplicate-punctuation normalization
//
// Everything here is pure Swift and unit-tested (Tests/local_ai_tests.swift).
// The rule: never remove a token that can carry meaning
// ("actually", "haan", "মানে" mid-sentence) — only clear fillers.
// ============================================================

import Foundation

// MARK: - ASR result types (shared with LocalWhisperEngine)

struct WhisperSegment: Sendable {
    let text: String
    let startSeconds: Double
    let endSeconds: Double
}

struct LocalWhisperResult: Sendable {
    let text: String
    let detectedLanguage: String
    let loadMilliseconds: Int
    let transcribeMilliseconds: Int
    /// Text segments with timings (empty if timings unavailable).
    let segments: [WhisperSegment]
    /// VAD speech spans in seconds (empty unless a VAD model was used).
    let vadSpans: [ClosedRange<Double>]
}

// MARK: - Aggressiveness

enum DisfluencyAggressiveness: String, Codable, CaseIterable, Sendable {
    case literal    // touch nothing but whitespace
    case light      // obvious "um/uh" only
    case standard   // fillers + repeated false starts
    case polished   // + tighten spacing around pauses (still no paraphrase)

    var displayName: String {
        switch self {
        case .literal:  return "Literal"
        case .light:    return "Light"
        case .standard: return "Standard"
        case .polished: return "Polished"
        }
    }

    var removesFillers: Bool { self != .literal }
    var removesFalseStarts: Bool { self == .standard || self == .polished }
}

// MARK: - Analysis result

struct FillerHit: Sendable, Equatable {
    let token: String
    let range: Range<String.Index>
}

struct SelfCorrectionEvent: Sendable, Equatable {
    let marker: String                // e.g. "no actually"
    let discardedText: String         // best guess at the abandoned span
    let keptText: String              // best guess at the intended span
}

struct PauseEvent: Sendable, Equatable {
    enum Kind: String, Sendable { case micro, clause, hesitation, boundary }
    let afterSeconds: Double
    let gapSeconds: Double
    let kind: Kind
}

struct SpeechAnalysis: Sendable {
    let cleanedText: String
    let fillersRemoved: [String]
    let corrections: [SelfCorrectionEvent]
    let pauses: [PauseEvent]
    let speechSeconds: Double
    let silenceSeconds: Double
    let wordsPerMinute: Double?
    /// True when the cleanup made no material change (LLM can be skipped for
    /// simple, short, clean utterances).
    let isTrivialResult: Bool
}

// MARK: - Filler dictionaries

enum FillerLexicon {

    /// Always-safe fillers — standalone hesitation sounds. Removed at .light+.
    static let hardFillers: Set<String> = [
        "um", "umm", "ummm", "uh", "uhh", "uhhh", "erm", "ehm", "hmm", "hm",
        "er", "ah", "aah", "mmm",
        // Hindi/Hinglish hesitation sounds
        "आ", "अं", "हम्म",
        // Bengali hesitation sounds (conservative)
        "উম", "আহ", "এ্যা",
    ]

    /// Context-dependent — only removed when clearly a discourse filler
    /// (sentence-initial or between commas), never mid-clause.
    static let softFillers: Set<String> = [
        "basically", "literally", "actually", "like",
        "matlab", "yaar",  // only as trailing/standalone filler
        "মানে", "আসলে",
    ]

    /// Multi-word soft fillers.
    static let softPhrases: [String] = [
        "you know", "i mean", "sort of", "kind of", "kinda", "sorta",
    ]
}

// MARK: - Self-correction markers

enum CorrectionLexicon {
    static let markers: [String] = [
        "no actually", "no wait", "actually no", "sorry i mean", "sorry", "wait no",
        "scratch that", "i mean", "or rather", "let me rephrase",
        // Hindi/Hinglish
        "nahi nahi", "arre nahi", "matlab nahi", "sorry matlab",
        // Bengali
        "na na", "mane na",
        // Other languages already handled by the LLM prompt; a few common ones:
        "de fapt", "nu stai", "perdón", "non",
    ]
}

// MARK: - Detectors

enum FillerDetector {

    /// Remove fillers per `level`. Returns (cleanedText, removedTokens).
    static func strip(_ text: String, level: DisfluencyAggressiveness,
                      language: LanguageSelection.Language) -> (String, [String]) {
        guard level.removesFillers, !text.isEmpty else { return (text, []) }

        var removed: [String] = []
        // Tokenize on whitespace but keep trailing punctuation attached.
        var words = text.split(separator: " ", omittingEmptySubsequences: true).map(String.init)

        func core(_ w: String) -> String {
            w.lowercased().trimmingCharacters(in: CharacterSet.punctuationCharacters)
        }

        // 1. Hard fillers — drop wherever they stand alone.
        words = words.filter { w in
            if FillerLexicon.hardFillers.contains(core(w)) {
                removed.append(core(w)); return false
            }
            return true
        }

        // 2. Soft fillers — only sentence-initial or fenced by commas.
        if level == .standard || level == .polished {
            var result: [String] = []
            for (i, w) in words.enumerated() {
                let c = core(w)
                let isSoft = FillerLexicon.softFillers.contains(c)
                let prev = i > 0 ? words[i - 1] : nil
                let atStart = i == 0 || (prev?.hasSuffix(".") ?? false) || (prev?.hasSuffix(",") ?? false)
                                     || (prev?.hasSuffix("?") ?? false) || (prev?.hasSuffix("!") ?? false)
                let commaAfter = w.hasSuffix(",")
                if isSoft && (atStart || commaAfter) {
                    removed.append(c)
                    continue
                }
                result.append(w)
            }
            words = result
        }

        var cleaned = words.joined(separator: " ")

        // 3. Multi-word soft phrases (sentence-initial only).
        if level == .standard || level == .polished {
            for phrase in FillerLexicon.softPhrases {
                let patterns = ["^\(phrase),?\\s+", "(?<=[.!?]\\s)\(phrase),?\\s+"]
                for p in patterns {
                    if let re = try? NSRegularExpression(pattern: p, options: [.caseInsensitive]) {
                        let r = NSRange(cleaned.startIndex..., in: cleaned)
                        if re.firstMatch(in: cleaned, range: r) != nil { removed.append(phrase) }
                        cleaned = re.stringByReplacingMatches(in: cleaned, range: r, withTemplate: "")
                    }
                }
            }
        }

        // 4. Collapse immediate word repetitions ("the the", "I I", "woh woh").
        if level.removesFalseStarts {
            let toks = cleaned.split(separator: " ").map(String.init)
            var dedup: [String] = []
            for t in toks {
                if let last = dedup.last, core(last) == core(t), core(t).count <= 4 {
                    removed.append(core(t)); continue
                }
                dedup.append(t)
            }
            cleaned = dedup.joined(separator: " ")
        }

        return (TextNormalizer.tidy(cleaned), removed)
    }
}

enum SelfCorrectionDetector {
    /// Detect (don't apply) self-corrections. The LLM cleanup does the collapse
    /// using the app's existing, well-tuned rules.
    static func detect(_ text: String) -> [SelfCorrectionEvent] {
        let lower = " " + text.lowercased() + " "
        var events: [SelfCorrectionEvent] = []
        for marker in CorrectionLexicon.markers {
            let needle = " \(marker) "
            guard let r = lower.range(of: needle) else { continue }
            let before = String(lower[lower.startIndex..<r.lowerBound])
                .split(separator: " ").suffix(4).joined(separator: " ")
            let after = String(lower[r.upperBound...])
                .split(separator: " ").prefix(4).joined(separator: " ")
            events.append(SelfCorrectionEvent(marker: marker,
                                              discardedText: before.trimmingCharacters(in: .whitespaces),
                                              keptText: after.trimmingCharacters(in: .whitespaces)))
        }
        return events
    }
}

enum PauseAnalyzer {
    /// Classify gaps between consecutive speech spans.
    static func pauses(from spans: [ClosedRange<Double>]) -> [PauseEvent] {
        guard spans.count > 1 else { return [] }
        var out: [PauseEvent] = []
        for i in 1..<spans.count {
            let gap = spans[i].lowerBound - spans[i - 1].upperBound
            guard gap > 0.12 else { continue }
            let kind: PauseEvent.Kind
            switch gap {
            case ..<0.25:  kind = .micro
            case ..<0.70:  kind = .clause
            case ..<1.50:  kind = .hesitation
            default:       kind = .boundary
            }
            out.append(PauseEvent(afterSeconds: spans[i - 1].upperBound, gapSeconds: gap, kind: kind))
        }
        return out
    }
}

// MARK: - Whitespace / punctuation normalizer

enum TextNormalizer {
    static func tidy(_ s: String) -> String {
        var t = s
        t = t.replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+([,.;:!?])"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"([,.;:!?]){2,}"#, with: "$1", options: .regularExpression)
        t = t.replacingOccurrences(of: #"\s+([।॥])"#, with: "$1", options: .regularExpression)
        return t.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Whisper Mode (quiet speech gain)

enum WhisperModeGain {
    /// If the audio is quiet but has real signal, apply a bounded gain so Whisper
    /// doesn't treat whispering as noise. Never amplifies pure silence; clamps to
    /// avoid clipping.
    static func apply(_ samples: [Float]) -> [Float] {
        guard samples.count > 3200 else { return samples }
        var peak: Float = 0
        for s in samples { let a = abs(s); if a > peak { peak = a } }
        guard peak > 0.002, peak < 0.15 else { return samples }   // quiet but present
        let gain = min(0.35 / peak, 8.0)
        guard gain > 1.2 else { return samples }
        return samples.map { Swift.max(-1.0, Swift.min(1.0, $0 * gain)) }
    }
}

// MARK: - Orchestrator

enum SpeechAnalysisService {

    static func analyze(rawText: String,
                        result: LocalWhisperResult?,
                        level: DisfluencyAggressiveness,
                        language: LanguageSelection.Language) -> SpeechAnalysis {

        let spans = result?.vadSpans ?? []
        let audioSeconds = result?.segments.last?.endSeconds
            ?? spans.last?.upperBound ?? 0
        let speechSeconds = spans.reduce(0) { $0 + ($1.upperBound - $1.lowerBound) }
        let silenceSeconds = max(0, audioSeconds - speechSeconds)

        let (cleaned, removed) = FillerDetector.strip(rawText, level: level, language: language)
        let corrections = SelfCorrectionDetector.detect(rawText)
        let pauses = PauseAnalyzer.pauses(from: spans)

        let wordCount = cleaned.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
        let wpm: Double? = speechSeconds > 1
            ? Double(wordCount) / (speechSeconds / 60.0)
            : nil

        let trivial = removed.isEmpty
            && corrections.isEmpty
            && cleaned == TextNormalizer.tidy(rawText)
            && wordCount <= 6

        return SpeechAnalysis(cleanedText: cleaned,
                              fillersRemoved: removed,
                              corrections: corrections,
                              pauses: pauses,
                              speechSeconds: speechSeconds,
                              silenceSeconds: silenceSeconds,
                              wordsPerMinute: wpm,
                              isTrivialResult: trivial)
    }
}
