import Foundation

// MARK: - Snippet Model

struct VoiceSnippet: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var trigger: String          // e.g. "mera address", "my signature"
    var replacement: String      // The expanded text
    var isEnabled: Bool = true
    var usageCount: Int = 0
    var lastUsed: Date? = nil

    static func == (lhs: VoiceSnippet, rhs: VoiceSnippet) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Snippet Engine

final class SnippetEngine {
    private let storageKey = "voice_snippets_v1"
    private let fuzzyMatchThreshold: Double = 0.85

    private(set) var snippets: [VoiceSnippet] = []
    private var normalizedTriggerCache: [UUID: String] = [:]

    init() {
        load()
    }

    // MARK: - Snippet Matching

    /// Runs snippet matching on raw transcript BEFORE post-processing.
    /// Returns the text with all matched snippets expanded, or the original if none match.
    func process(_ transcript: String) -> String {
        guard !snippets.isEmpty else { return transcript }

        let enabledSnippets = snippets.filter { $0.isEnabled }
        guard !enabledSnippets.isEmpty else { return transcript }

        var result = transcript

        // Sort by trigger length descending (longest match wins)
        let sorted = enabledSnippets.sorted { $0.trigger.count > $1.trigger.count }

        for snippet in sorted {
            let normalizedTrigger = normalizedTriggerCache[snippet.id]
                ?? normalize(snippet.trigger)
            let normalizedResult = normalize(result)

            // Exact match (case-insensitive, script-insensitive)
            if let range = normalizedResult.range(of: normalizedTrigger,
                                                   options: [.caseInsensitive, .diacriticInsensitive]) {
                // Find the corresponding range in the original string
                let startIndex = result.index(result.startIndex,
                                              offsetBy: normalizedResult.distance(from: normalizedResult.startIndex, to: range.lowerBound))
                let endIndex = result.index(result.startIndex,
                                            offsetBy: normalizedResult.distance(from: normalizedResult.startIndex, to: range.upperBound))
                result.replaceSubrange(startIndex..<endIndex, with: snippet.replacement)
                recordUsage(for: snippet.id)
                continue
            }

            // Fuzzy match — check if any window of words has high similarity
            let words = normalizedResult.split(separator: " ").map(String.init)
            let triggerWords = normalizedTrigger.split(separator: " ").map(String.init)
            let windowSize = triggerWords.count

            guard windowSize > 0, words.count >= windowSize else { continue }

            for windowStart in 0...(words.count - windowSize) {
                let window = words[windowStart..<(windowStart + windowSize)].joined(separator: " ")
                let similarity = stringSimilarity(window, normalizedTrigger)

                if similarity >= fuzzyMatchThreshold {
                    // Replace the fuzzy-matched window with the snippet replacement
                    // Rebuild the result
                    let before = words[0..<windowStart].joined(separator: " ")
                    let after = words[(windowStart + windowSize)...].joined(separator: " ")
                    var parts: [String] = []
                    if !before.isEmpty { parts.append(before) }
                    parts.append(snippet.replacement)
                    if !after.isEmpty { parts.append(after) }
                    result = parts.joined(separator: " ")
                    recordUsage(for: snippet.id)
                    break
                }
            }
        }

        return result
    }

    // MARK: - CRUD

    func addSnippet(_ snippet: VoiceSnippet) {
        let s = snippet
        if s.trigger.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        snippets.append(s)
        rebuildCache()
        save()
    }

    func updateSnippet(_ snippet: VoiceSnippet) {
        if let index = snippets.firstIndex(where: { $0.id == snippet.id }) {
            snippets[index] = snippet
            rebuildCache()
            save()
        }
    }

    func deleteSnippet(id: UUID) {
        snippets.removeAll { $0.id == id }
        normalizedTriggerCache.removeValue(forKey: id)
        save()
    }

    func importSnippets(from data: Data) throws {
        let imported = try JSONDecoder().decode([VoiceSnippet].self, from: data)
        for snippet in imported {
            if !snippets.contains(where: { $0.trigger.lowercased() == snippet.trigger.lowercased() }) {
                snippets.append(snippet)
            }
        }
        rebuildCache()
        save()
    }

    func exportSnippets() throws -> Data {
        try JSONEncoder().encode(snippets)
    }

    // MARK: - Pre-loaded Suggestions

    static let suggestedSnippets: [(trigger: String, placeholder: String)] = [
        ("mera address", "Your address here..."),
        ("my signature", "Your email signature..."),
        ("my upi id", "Your UPI ID..."),
        ("my intro", "Your elevator pitch / intro..."),
        ("calendar link", "Your Calendly/Cal.com link...")
    ]

    // MARK: - Private

    private func recordUsage(for id: UUID) {
        if let index = snippets.firstIndex(where: { $0.id == id }) {
            snippets[index].usageCount += 1
            snippets[index].lastUsed = Date()
            save()
        }
    }

    private func normalize(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    private func rebuildCache() {
        normalizedTriggerCache = [:]
        for snippet in snippets {
            normalizedTriggerCache[snippet.id] = normalize(snippet.trigger)
        }
    }

    /// Levenshtein-based string similarity (0.0 to 1.0)
    private func stringSimilarity(_ a: String, _ b: String) -> Double {
        let aChars = Array(a)
        let bChars = Array(b)
        let aLen = aChars.count
        let bLen = bChars.count

        guard aLen > 0, bLen > 0 else { return 0.0 }
        guard aLen + bLen > 0 else { return 1.0 }

        var matrix = [[Int]](repeating: [Int](repeating: 0, count: bLen + 1), count: aLen + 1)

        for i in 0...aLen { matrix[i][0] = i }
        for j in 0...bLen { matrix[0][j] = j }

        for i in 1...aLen {
            for j in 1...bLen {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                matrix[i][j] = min(
                    matrix[i - 1][j] + 1,
                    matrix[i][j - 1] + 1,
                    matrix[i - 1][j - 1] + cost
                )
            }
        }

        let distance = Double(matrix[aLen][bLen])
        let maxLen = Double(max(aLen, bLen))
        return 1.0 - (distance / maxLen)
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode([VoiceSnippet].self, from: data) {
            snippets = stored
        }
        rebuildCache()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(snippets) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
