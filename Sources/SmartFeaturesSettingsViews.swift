import SwiftUI

// MARK: - Smart Modes Settings

struct SmartModesSettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Smart Modes")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("FlowKeys automatically adjusts dictation behavior based on context or manual selection.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Auto-Mode Toggle
                Toggle(isOn: Binding(
                    get: { appState.dictationModeStore.autoModeEnabled },
                    set: { appState.dictationModeStore.autoModeEnabled = $0 }
                )) {
                    VStack(alignment: .leading) {
                        Text("Auto-Switch by App")
                            .font(.headline)
                        Text("Automatically activate modes based on the app you are typing in (e.g. Code mode in VS Code, Email mode in Mail).")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // Mode List
                VStack(spacing: 12) {
                    ForEach(appState.dictationModeStore.modes) { mode in
                        ModeRow(mode: mode)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)
        }
    }
}

private struct ModeRow: View {
    let mode: DictationMode
    
    var body: some View {
        HStack(spacing: 16) {
            Text(mode.icon)
                .font(.system(size: 24))
                .frame(width: 40, height: 40)
                .background(Color(hex: mode.color).opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(mode.name)
                        .font(.headline)
                    if mode.isBuiltIn {
                        Text("Built-in")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .foregroundColor(.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                
                if !mode.activateForApps.isEmpty {
                    Text("Auto-activates in: \(mode.activateForApps.count) apps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Button("Edit") {
                // Future expansion: Edit custom modes
            }
            .disabled(mode.isBuiltIn) // Temporarily disable built-in editing
        }
        .padding()
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Quick Snippets Settings

struct SnippetsSettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingAddPopover = false
    @State private var newTrigger = ""
    @State private var newReplacement = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Quick Snippets")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Expand short phrases into full text (e.g. say \"my sign\" → types \"Best regards, Adarsha\").")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    newTrigger = ""
                    newReplacement = ""
                    showingAddPopover = true
                } label: {
                    Label("Add Snippet", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .popover(isPresented: $showingAddPopover, arrowEdge: .bottom) {
                    addSnippetForm
                }
            }
            .padding()
            
            Divider()
            
            if appState.snippetEngine.snippets.isEmpty {
                emptySnippetsState
            } else {
                List {
                    ForEach(appState.snippetEngine.snippets) { snippet in
                        SnippetRow(snippet: snippet)
                            .environmentObject(appState)
                    }
                    .onDelete { indices in
                        for index in indices {
                            let id = appState.snippetEngine.snippets[index].id
                            appState.snippetEngine.deleteSnippet(id: id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private var emptySnippetsState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "text.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No Snippets Found")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Add terms like 'my intro' or 'my upi id' to instantly expand them while dictating.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Button("Add Suggested") {
                for suggestion in SnippetEngine.suggestedSnippets {
                    let snippet = VoiceSnippet(trigger: suggestion.trigger, replacement: suggestion.placeholder)
                    appState.snippetEngine.addSnippet(snippet)
                }
            }
            .buttonStyle(.bordered)
            Spacer()
        }
    }
    
    private var addSnippetForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New Snippet")
                .font(.headline)
            
            VStack(alignment: .leading) {
                Text("When I say:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("e.g. my address", text: $newTrigger)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading) {
                Text("Replace it with:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextEditor(text: $newReplacement)
                    .frame(height: 80)
                    .font(.body)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))
            }
            
            HStack {
                Spacer()
                Button("Cancel") { showingAddPopover = false }
                    .keyboardShortcut(.cancelAction)
                Button("Add") {
                    let snippet = VoiceSnippet(trigger: newTrigger, replacement: newReplacement)
                    appState.snippetEngine.addSnippet(snippet)
                    showingAddPopover = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newTrigger.trimmingCharacters(in: .whitespaces).isEmpty || newReplacement.trimmingCharacters(in: .whitespaces).isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
    }
}

private struct SnippetRow: View {
    @EnvironmentObject var appState: AppState
    let snippet: VoiceSnippet
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.trigger)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text(snippet.replacement)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Toggle("", isOn: Binding(
                    get: { snippet.isEnabled },
                    set: { val in
                        var s = snippet
                        s.isEnabled = val
                        appState.snippetEngine.updateSnippet(s)
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                
                Text(snippet.usageCount > 0 ? "Used \(snippet.usageCount) times" : "Never used")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Dictionary Settings

struct DictionarySettingsView: View {
    @EnvironmentObject var appState: AppState
    @State private var newTerm = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Personal Vocabulary")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("FlowKeys automatically learns proper nouns and complex words you use often.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            
            Divider()
            
            // Add custom term
            HStack {
                TextField("Add name, brand, or technical term...", text: $newTerm)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addTerm)
                Button(action: addTerm) {
                    Image(systemName: "plus")
                }
                .disabled(newTerm.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            
            Divider()
            
            // List
            if appState.personalDictionary.entries.isEmpty {
                emptyDictionaryState
            } else {
                List {
                    ForEach(appState.personalDictionary.entries.sorted(by: { $0.lastUsed > $1.lastUsed })) { entry in
                        DictionaryRow(entry: entry)
                            .environmentObject(appState)
                    }
                    .onDelete { indices in
                        for index in indices {
                            let id = appState.personalDictionary.entries.sorted(by: { $0.lastUsed > $1.lastUsed })[index].id
                            appState.personalDictionary.deleteEntry(id: id)
                        }
                    }
                }
                .listStyle(.inset)
            }
        }
    }
    
    private func addTerm() {
        appState.personalDictionary.addTerm(newTerm)
        newTerm = ""
    }
    
    private var emptyDictionaryState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "character.book.closed")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("Dictionary is Learning")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("Speak naturally! FlowKeys will automatically identify and learn uncommon names and terms you use 3 or more times.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
            Spacer()
        }
    }
}

private struct DictionaryRow: View {
    @EnvironmentObject var appState: AppState
    let entry: DictionaryEntry
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.term)
                    .font(.body)
                    .fontWeight(.medium)
                HStack(spacing: 8) {
                    Text(sourceLabel)
                        .font(.caption2)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(sourceColor.opacity(0.2))
                        .foregroundColor(sourceColor)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("Used \(entry.frequency) times")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Toggle("Use in Prompt", isOn: Binding(
                get: { entry.includeInPrompt },
                set: { val in
                    var e = entry
                    e.includeInPrompt = val
                    appState.personalDictionary.updateEntry(e)
                }
            ))
            .toggleStyle(.checkbox)
        }
        .padding(.vertical, 4)
    }
    
    private var sourceLabel: String {
        switch entry.source {
        case .manual: return "Manual"
        case .autoLearned: return "Auto-learned"
        case .suggested: return "Suggested"
        }
    }
    
    private var sourceColor: Color {
        switch entry.source {
        case .manual: return .blue
        case .autoLearned: return .green
        case .suggested: return .purple
        }
    }
}

// Extension to support hex colors
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
