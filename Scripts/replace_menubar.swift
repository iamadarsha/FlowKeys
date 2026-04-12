import Foundation

let path = "Sources/MenuBarView.swift"
var content = try! String(contentsOfFile: path)

// 1. Width 300
content = content.replacingOccurrences(of: ".frame(width: 320)", with: ".frame(width: 300)")

// 2. Header Section
let oldHeader = """
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                    Text("FlowKeys")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/iamadarsha/FlowKeys") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: .showSettings, object: nil)
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(statusText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(appState.isRecording ? .red : .primary)
                
                Spacer()
                
                if !shortcutHint.isEmpty {
                    Text(shortcutHint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
"""

let newHeader = """
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(accentColor)
                    Text("FlowKeys")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/iamadarsha/FlowKeys") {
                            NSWorkspace.shared.open(url)
                        }
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                    
                    Button(action: {
                        NotificationCenter.default.post(name: .showSettings, object: nil)
                    }) {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                    }.buttonStyle(.plain)
                }
            }
            
            HStack {
                if !shortcutHint.isEmpty {
                    Text(shortcutHint)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(4)
                } else {
                    Text("No shortcuts set")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text("\\(appState.activeTranscriptionProvider.displayName) \\(appState.activeTranscriptionProvider == .groq ? "⚡️" : "")")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(accentColor.opacity(0.15))
                    .cornerRadius(10)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }
"""

content = content.replacingOccurrences(of: oldHeader, with: newHeader)

// 3. Language & Tone & Recent Sections
let oldLanguage = """
    private var languageModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LANGUAGE")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
            
            Picker("Language Mode", selection: $appState.languageMode) {
                Text("MIX 🇮🇳").tag(UserLanguageMode.hinglish)
                Text("HI 🇮🇳").tag(UserLanguageMode.pureHindi)
                Text("EN").tag(UserLanguageMode.pureEnglish)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }
"""

let newLanguage = """
    private var languageModeSection: some View {
        HStack(spacing: 8) {
            Image(systemName: "globe")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            
            Picker("Language Mode", selection: $appState.languageMode) {
                Text("MIX 🇮🇳").tag(UserLanguageMode.hinglish)
                Text("HI 🇮🇳").tag(UserLanguageMode.pureHindi)
                Text("EN").tag(UserLanguageMode.pureEnglish)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: .infinity)
            .cornerRadius(6)
        }
    }
"""
content = content.replacingOccurrences(of: oldLanguage, with: newLanguage)

let oldTone = """
    private var toneModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("TONE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: {
                    appState.selectedSettingsTab = .general
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }) {
                    Text("Edit modes")
                        .font(.system(size: 10))
                        .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
            }

            let tones: [(icon: String, name: String, id: UUID)] = [
                ("🗣️", "Casual", DictationMode.casualHinglish.id),
                ("📧", "Email", DictationMode.professionalEmail.id),
                ("💻", "Code", DictationMode.codeAndTerminal.id),
                ("📝", "Notes", DictationMode.meetingNotes.id),
                ("📱", "Social", DictationMode.socialMedia.id),
                ("🔇", "Literal", DictationMode.literalNoEdit.id)
            ]

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(tones, id: \\.id) { tone in
                    toneButton(icon: tone.icon, name: tone.name, id: tone.id)
                }
            }
        }
    }

    private func toneButton(icon: String, name: String, id: UUID) -> some View {
        let isActive = appState.dictationModeStore.activeModeID == id

        return Button(action: {
            appState.dictationModeStore.activeModeID = isActive ? nil : id
        }) {
            VStack(spacing: 4) {
                Text(icon).font(.system(size: 16))
                Text(name).font(.system(size: 11, weight: isActive ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? accentColor : Color.gray.opacity(0.2), lineWidth: 1)
            )
            .foregroundColor(isActive ? accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
"""

let newTone = """
    private var toneModeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
                Spacer()
                Button(action: {
                    appState.selectedSettingsTab = .general
                    NotificationCenter.default.post(name: .showSettings, object: nil)
                }) {
                    Text("Edit modes")
                        .font(.system(size: 10))
                        .foregroundColor(accentColor)
                }
                .buttonStyle(.plain)
            }

            let tones: [(icon: String, name: String, id: UUID)] = [
                ("bubble.left.fill", "Casual", DictationMode.casualHinglish.id),
                ("envelope.fill", "Email", DictationMode.professionalEmail.id),
                ("chevron.left.forwardslash.chevron.right", "Code", DictationMode.codeAndTerminal.id),
                ("note.text", "Notes", DictationMode.meetingNotes.id),
                ("heart.fill", "Social", DictationMode.socialMedia.id),
                ("equal.circle.fill", "Literal", DictationMode.literalNoEdit.id)
            ]

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(tones, id: \\.id) { tone in
                    toneButton(icon: tone.icon, name: tone.name, id: tone.id)
                }
            }
        }
    }

    private func toneButton(icon: String, name: String, id: UUID) -> some View {
        let isActive = appState.dictationModeStore.activeModeID == id

        return Button(action: {
            appState.dictationModeStore.activeModeID = isActive ? nil : id
        }) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 14))
                Text(name).font(.system(size: 10, weight: isActive ? .semibold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? accentColor : Color.gray.opacity(0.2), lineWidth: 1.5)
            )
            .foregroundColor(isActive ? accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
"""
content = content.replacingOccurrences(of: oldTone, with: newTone)

let oldRecent = """
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("RECENT")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.secondary)
"""

let newRecent = """
    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "clock")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }
"""
content = content.replacingOccurrences(of: oldRecent, with: newRecent)


// 4. Remove provider from actions
let oldActions = """
            HStack {
                Text("Provider: \\(appState.activeTranscriptionProvider.displayName) \\(appState.activeTranscriptionProvider == .groq ? "⚡️" : "")")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                Spacer()
                Button("Transcribe File...") {
                    NotificationCenter.default.post(name: .showFileTranscription, object: nil)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(accentColor)
                .buttonStyle(.plain)
            }
"""
let newActions = """
            HStack {
                Spacer()
                Button("Transcribe File...") {
                    NotificationCenter.default.post(name: .showFileTranscription, object: nil)
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(accentColor)
                .buttonStyle(.plain)
            }
"""
content = content.replacingOccurrences(of: oldActions, with: newActions)

try! content.write(toFile: path, atomically: true, encoding: .utf8)
