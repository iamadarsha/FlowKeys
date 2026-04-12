import Foundation

// MARK: - Dictionary Entry

struct DictionaryEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var term: String
    var frequency: Int = 1
    var source: EntrySource
    var lastUsed: Date = Date()
    var includeInPrompt: Bool = true

    static func == (lhs: DictionaryEntry, rhs: DictionaryEntry) -> Bool {
        lhs.id == rhs.id
    }
}

enum EntrySource: String, Codable {
    case manual
    case autoLearned
    case suggested
}

// MARK: - Personal Dictionary

final class PersonalDictionary {
    private let storageKey = "personal_dictionary_v1"
    private let maxEntries = 500
    private let maxPromptTerms = 50
    private let autoLearnThreshold = 3

    private(set) var entries: [DictionaryEntry] = []

    // Frequency tracker for auto-learn (term → count)
    private var frequencyTracker: [String: Int] = [:]
    private let frequencyTrackerKey = "term_frequency_tracker_v1"

    init() {
        load()
        loadFrequencyTracker()
    }

    // MARK: - Prompt Injection

    /// Returns the top terms for injection into the LLM post-processing prompt.
    /// Priority: most recently used, most frequent. Capped at 50 terms.
    func termsForPromptInjection() -> [String] {
        entries
            .filter { $0.includeInPrompt }
            .sorted {
                // Primary: recently used first. Secondary: higher frequency first.
                if Calendar.current.isDate($0.lastUsed, inSameDayAs: $1.lastUsed) {
                    return $0.frequency > $1.frequency
                }
                return $0.lastUsed > $1.lastUsed
            }
            .prefix(maxPromptTerms)
            .map { $0.term }
    }

    /// Returns a comma-separated string ready for prompt injection.
    func promptInjectionString() -> String {
        let terms = termsForPromptInjection()
        guard !terms.isEmpty else { return "" }
        return terms.joined(separator: ", ")
    }

    // MARK: - Auto-Learn Pipeline

    /// Called after every successful transcription. Extracts potential new terms
    /// and tracks their frequency. Terms appearing 3+ times get auto-added.
    func processTranscript(_ transcript: String) -> [String] {
        let words = extractNotableTerms(from: transcript)
        var newlyLearned: [String] = []

        for word in words {
            let normalized = word.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, normalized.count >= 2 else { continue }
            guard !isCommonEnglishWord(normalized) else { continue }
            guard !entries.contains(where: { $0.term.caseInsensitiveCompare(normalized) == .orderedSame }) else {
                // Already in dictionary — bump frequency
                if let idx = entries.firstIndex(where: { $0.term.caseInsensitiveCompare(normalized) == .orderedSame }) {
                    entries[idx].frequency += 1
                    entries[idx].lastUsed = Date()
                }
                continue
            }

            frequencyTracker[normalized.lowercased(), default: 0] += 1

            if frequencyTracker[normalized.lowercased(), default: 0] >= autoLearnThreshold {
                let entry = DictionaryEntry(
                    term: normalized,
                    frequency: frequencyTracker[normalized.lowercased(), default: 0],
                    source: .autoLearned,
                    lastUsed: Date(),
                    includeInPrompt: true
                )
                addEntry(entry)
                newlyLearned.append(normalized)
                frequencyTracker.removeValue(forKey: normalized.lowercased())
            }
        }

        saveFrequencyTracker()
        save()
        return newlyLearned
    }

    // MARK: - CRUD

    func addEntry(_ entry: DictionaryEntry) {
        guard entries.count < maxEntries else { return }
        guard !entries.contains(where: { $0.term.caseInsensitiveCompare(entry.term) == .orderedSame }) else { return }
        entries.append(entry)
        save()
    }

    func addTerm(_ term: String, source: EntrySource = .manual) {
        let trimmed = term.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let entry = DictionaryEntry(term: trimmed, source: source)
        addEntry(entry)
    }

    func addTerms(_ terms: [String], source: EntrySource = .manual) {
        for term in terms {
            addTerm(term, source: source)
        }
    }

    func updateEntry(_ entry: DictionaryEntry) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[index] = entry
            save()
        }
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    func toggleEntry(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries[index].includeInPrompt.toggle()
            save()
        }
    }

    var manualEntries: [DictionaryEntry] {
        entries.filter { $0.source == .manual }
    }

    var autoLearnedEntries: [DictionaryEntry] {
        entries.filter { $0.source == .autoLearned }
    }

    var suggestedEntries: [DictionaryEntry] {
        entries.filter { $0.source == .suggested }
    }

    // MARK: - Suggestions

    static let suggestedIndianNames: [String] = [
        "Rahul", "Priya", "Neha", "Vikram", "Shruti",
        "Aarav", "Kavya", "Arjun", "Ananya", "Rohan",
        "Meera", "Dhruv", "Ishaan", "Pooja", "Siddharth"
    ]

    static let suggestedBrands: [String] = [
        "Flipkart", "Swiggy", "Zomato", "Zerodha", "Razorpay",
        "PhonePe", "Paytm", "GPay", "Groww", "CRED",
        "Myntra", "BigBasket", "Blinkit", "MakeMyTrip", "Zepto"
    ]

    static let suggestedHinglishTerms: [String] = [
        "yaar", "bhai", "achha", "theek hai", "bindaas",
        "jugaad", "timepass", "chai", "masala", "desi"
    ]

    static let suggestedGenZTerms: [String] = [
        "lol", "brb", "idk", "ngl", "imo",
        "fwiw", "tbh", "fr fr", "lowkey", "vibe"
    ]

    // MARK: - Private

    private func extractNotableTerms(from text: String) -> [String] {
        // Extract capitalized words (potential proper nouns), brand names, etc.
        let words = text.components(separatedBy: .whitespacesAndNewlines)
        return words.filter { word in
            let trimmed = word.trimmingCharacters(in: .punctuationCharacters)
            guard trimmed.count >= 2 else { return false }
            // Capitalized word (not at sentence start heuristic: not after . or start)
            let first = trimmed.first!
            return first.isUppercase && !first.isNumber
        }.map { $0.trimmingCharacters(in: .punctuationCharacters) }
    }

    private func isCommonEnglishWord(_ word: String) -> Bool {
        // A minimal set of common English words to exclude from auto-learn
        let common: Set<String> = [
            "the", "and", "for", "are", "but", "not", "you", "all",
            "can", "had", "her", "was", "one", "our", "out", "has",
            "his", "how", "its", "may", "new", "now", "old", "see",
            "way", "who", "did", "got", "let", "say", "she", "too",
            "use", "been", "have", "from", "they", "this", "that",
            "will", "with", "just", "then", "than", "them", "when",
            "what", "some", "make", "like", "long", "much", "your",
            "very", "after", "also", "been", "come", "each", "made",
            "find", "here", "know", "many", "only", "over", "such",
            "take", "than", "well", "work", "call", "first", "could",
            "would", "should", "about", "right", "there", "think",
            "which", "still", "every", "these", "those", "where",
            "while", "world", "being", "house", "maybe", "after",
            "Today", "Please", "Thanks", "Hello", "Sorry",
            "Monday", "Tuesday", "Wednesday", "Thursday", "Friday",
            "Saturday", "Sunday", "January", "February", "March",
            "April", "May", "June", "July", "August", "September",
            "October", "November", "December"
        ]
        return common.contains(word.lowercased()) || common.contains(word)
    }

    // MARK: - Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode([DictionaryEntry].self, from: data) {
            entries = stored
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFrequencyTracker() {
        if let data = UserDefaults.standard.data(forKey: frequencyTrackerKey),
           let stored = try? JSONDecoder().decode([String: Int].self, from: data) {
            frequencyTracker = stored
        }
    }

    private func saveFrequencyTracker() {
        if let data = try? JSONEncoder().encode(frequencyTracker) {
            UserDefaults.standard.set(data, forKey: frequencyTrackerKey)
        }
    }
}
