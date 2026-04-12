import Foundation

// MARK: - Dictation Mode

struct DictationMode: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var icon: String            // Emoji or SF Symbol
    var color: String           // Hex color string
    var systemPromptOverride: String?
    var appendToBasePrompt: String?
    var languageOverride: UserLanguageMode?
    var activateForApps: [String]   // Bundle IDs
    var isBuiltIn: Bool

    static func == (lhs: DictationMode, rhs: DictationMode) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Built-in Modes

extension DictationMode {

    static let builtInModes: [DictationMode] = [
        casualHinglish,
        professionalEmail,
        codeAndTerminal,
        meetingNotes,
        socialMedia,
        literalNoEdit,
        hindiOnly
    ]

    // ─── 1. Casual Hinglish 🗣️ ────────────────────────────────────────
    static let casualHinglish = DictationMode(
        id: UUID(uuidString: "00000001-0001-0001-0001-000000000001")!,
        name: "Casual",
        icon: "🗣️",
        color: "#FF6B35",
        systemPromptOverride: nil,
        appendToBasePrompt: """
Keep the response conversational and casual. \
Preserve all Hinglish, yaar/bhai/na particles. \
Short sentences. Very natural Indian tone.
Gen Z and millennial friendly — lol, ngl, fr, lowkey, vibe, \
slay, rizz, no cap, periodt, understood as valid terms.
SMS abbreviations: u=you, r=are, k=okay, tmrw=tomorrow, \
ngl=not gonna lie, imo=in my opinion, tbh=to be honest, \
lmk=let me know, hmu=hit me up, idk=I don't know.
DO NOT expand SMS abbreviations if user said them intentionally.
""",
        languageOverride: .hinglish,
        activateForApps: [
            "net.whatsapp.WhatsApp",
            "org.telegram.desktop",
            "com.apple.MobileSMS"
        ],
        isBuiltIn: true
    )

    // ─── 2. Professional Email 📧 ─────────────────────────────────────
    static let professionalEmail = DictationMode(
        id: UUID(uuidString: "00000002-0002-0002-0002-000000000002")!,
        name: "Email",
        icon: "📧",
        color: "#4A90E2",
        systemPromptOverride: nil,
        appendToBasePrompt: """
Format as professional Indian business email.
Use formal but warm tone — Indian professional culture.
'Please do the needful' and 'kindly revert' are valid Indian English.
Add proper salutation and closing if speaker includes them.
Fix grammar fully. No Hinglish unless speaker clearly intended it.
Subject line: if speaker says 'subject' at start, format it as the email subject line.
""",
        languageOverride: nil,
        activateForApps: [
            "com.apple.mail",
            "com.microsoft.Outlook",
            "com.google.Chrome",      // Gmail in Chrome
            "com.apple.Safari"        // Gmail in Safari
        ],
        isBuiltIn: true
    )

    // ─── 3. Code & Terminal 💻 ────────────────────────────────────────
    static let codeAndTerminal = DictationMode(
        id: UUID(uuidString: "00000003-0003-0003-0003-000000000003")!,
        name: "Code",
        icon: "💻",
        color: "#2ECC71",
        systemPromptOverride: """
You are a literal transcriber for a developer.
Output EXACTLY what was said with ZERO cleanup or interpretation.
Preserve technical terms, variable names, commands, operators.
Do not fix 'errors' — they may be intentional code syntax.
Only fix obvious Whisper mishearings of technical terms:
'git commit' not 'get commit', 'npm' not 'and pm',
'useState' not 'use state', 'async await' not 'a sync await',
'localhost' not 'local host', 'API' not 'a p i'.
Output raw text only.
""",
        appendToBasePrompt: nil,
        languageOverride: .pureEnglish,
        activateForApps: [
            "com.microsoft.VSCode",
            "com.apple.dt.Xcode",
            "com.apple.Terminal",
            "com.googlecode.iterm2",
            "com.todesktop.230313mzl4w4u92"  // Cursor
        ],
        isBuiltIn: true
    )

    // ─── 4. Meeting Notes 📝 ─────────────────────────────────────────
    static let meetingNotes = DictationMode(
        id: UUID(uuidString: "00000004-0004-0004-0004-000000000004")!,
        name: "Notes",
        icon: "📝",
        color: "#9B59B6",
        systemPromptOverride: nil,
        appendToBasePrompt: """
Format as structured meeting notes.
If speaker mentions action items, format as bullet points.
If speaker says a name + task → format as '@Name: task'
If speaker says 'decision:' → bold that line.
Timestamps: if speaker says 'at X minutes' → preserve.
Language: keep professional Hinglish or English as spoken.
""",
        languageOverride: nil,
        activateForApps: [
            "us.zoom.xos",
            "com.microsoft.teams2",
            "com.google.Chrome",      // Google Meet in Chrome
            "com.apple.FaceTime"
        ],
        isBuiltIn: true
    )

    // ─── 5. Social Media 📱 ──────────────────────────────────────────
    static let socialMedia = DictationMode(
        id: UUID(uuidString: "00000005-0005-0005-0005-000000000005")!,
        name: "Social",
        icon: "📱",
        color: "#E74C3C",
        systemPromptOverride: nil,
        appendToBasePrompt: """
Format for social media.
LinkedIn: professional tone, proper paragraphs, no slang.
Twitter/X: concise, punchy, preserve hashtags if mentioned, 280 chars preferred but don't cut meaning.
Instagram: casual, emoji-friendly tone.
Detect which platform from app context and adjust.
Gen Z language FULLY valid here: slay, no cap, lowkey, vibes, \
gyat, rizz, understood, periodt, it's giving, main character.
""",
        languageOverride: nil,
        activateForApps: [
            "com.atebits.Tweetie2",   // Twitter/X app
            "com.linkedin.LinkedIn",
            "com.burbn.instagram"
        ],
        isBuiltIn: true
    )

    // ─── 6. Literal / No-Edit 🔇 ────────────────────────────────────
    static let literalNoEdit = DictationMode(
        id: UUID(uuidString: "00000006-0006-0006-0006-000000000006")!,
        name: "Literal",
        icon: "🔇",
        color: "#95A5A6",
        systemPromptOverride: """
Return the raw transcription with ONLY obvious Whisper errors fixed. \
No style changes whatsoever. \
Preserve every word including fillers and repetitions.
""",
        appendToBasePrompt: nil,
        languageOverride: nil,
        activateForApps: [],
        isBuiltIn: true
    )

    // ─── 7. Hindi Only 🇮🇳 ──────────────────────────────────────────
    static let hindiOnly = DictationMode(
        id: UUID(uuidString: "00000007-0007-0007-0007-000000000007")!,
        name: "Hindi",
        icon: "🇮🇳",
        color: "#138808",
        systemPromptOverride: """
Output ONLY in Devanagari Hindi script.
If user spoke in Roman Hinglish, convert to proper Hindi.
Use natural, conversational Hindi — not textbook Hindi.
Avoid overly formal शुद्ध हिंदी unless the speech was formal.
""",
        appendToBasePrompt: nil,
        languageOverride: .pureHindi,
        activateForApps: [],
        isBuiltIn: true
    )
}

// MARK: - Mode Store (Persistence)

final class DictationModeStore {
    private let storageKey = "dictation_modes_v1"
    private let activeModeStorageKey = "active_dictation_mode_id"
    private let autoModeEnabledKey = "auto_dictation_mode_enabled"

    private(set) var modes: [DictationMode] = []
    var activeModeID: UUID? {
        didSet {
            if let id = activeModeID {
                UserDefaults.standard.set(id.uuidString, forKey: activeModeStorageKey)
            } else {
                UserDefaults.standard.removeObject(forKey: activeModeStorageKey)
            }
        }
    }
    var autoModeEnabled: Bool {
        didSet {
            UserDefaults.standard.set(autoModeEnabled, forKey: autoModeEnabledKey)
        }
    }

    var activeMode: DictationMode? {
        guard let id = activeModeID else { return nil }
        return modes.first(where: { $0.id == id })
    }

    init() {
        autoModeEnabled = UserDefaults.standard.object(forKey: autoModeEnabledKey) == nil
            ? true
            : UserDefaults.standard.bool(forKey: autoModeEnabledKey)

        if let idString = UserDefaults.standard.string(forKey: activeModeStorageKey) {
            activeModeID = UUID(uuidString: idString)
        }

        load()
    }

    // MARK: Matching

    /// Returns the best matching mode for a given app bundle ID.
    /// If auto-mode is disabled, returns nil.
    func modeForApp(bundleID: String) -> DictationMode? {
        guard autoModeEnabled else { return nil }
        return modes.first { mode in
            mode.activateForApps.contains(bundleID)
        }
    }

    /// Returns the effective mode: manual override > auto-match > nil
    func effectiveMode(forAppBundleID bundleID: String?) -> DictationMode? {
        // Manual override takes priority
        if let manual = activeMode { return manual }
        // Auto-match if enabled
        if let bundleID, let auto = modeForApp(bundleID: bundleID) { return auto }
        return nil
    }

    // MARK: CRUD

    func addMode(_ mode: DictationMode) {
        modes.append(mode)
        save()
    }

    func updateMode(_ mode: DictationMode) {
        if let index = modes.firstIndex(where: { $0.id == mode.id }) {
            modes[index] = mode
            save()
        }
    }

    func deleteMode(id: UUID) {
        modes.removeAll { $0.id == id }
        if activeModeID == id {
            activeModeID = nil
        }
        save()
    }

    // MARK: Persistence

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let stored = try? JSONDecoder().decode([DictationMode].self, from: data) {
            // Merge: keep stored custom modes, refresh built-ins
            let customModes = stored.filter { !$0.isBuiltIn }
            modes = DictationMode.builtInModes + customModes
        } else {
            modes = DictationMode.builtInModes
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(modes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
