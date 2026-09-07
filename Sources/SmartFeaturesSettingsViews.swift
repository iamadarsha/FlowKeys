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
                        .foregroundColor(KM.onSurface)
                    Text("FlowKeys automatically adjusts dictation behavior based on context or manual selection.")
                        .font(.body)
                        .foregroundColor(KM.muted)
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
                .background(KM.surfaceHi)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KM.outline, lineWidth: 1))
                .padding(.horizontal)
                
                // Mode List
                VStack(spacing: 12) {
                    ForEach(Array(appState.dictationModeStore.modes.enumerated()), id: \.element.id) { index, mode in
                        ModeRow(mode: mode)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.35, dampingFraction: 0.82).delay(Double(index) * 0.05), value: appState.dictationModeStore.modes.count)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 20)
        }
        .background(KM.bg)
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
                            .background(KM.accent.opacity(0.15))
                            .foregroundColor(KM.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
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
        .background(KM.surfaceHi)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(KM.outline, lineWidth: 1))
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
                        .foregroundColor(KM.onSurface)
                    Text("Expand short phrases into full text (e.g. say \"my sign\" → types \"Best regards, Adarsha\").")
                        .font(.body)
                        .foregroundColor(KM.muted)
                }
                Spacer()
                Button {
                    newTrigger = ""
                    newReplacement = ""
                    showingAddPopover = true
                } label: {
                    Label("Add Snippet", systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(LinearGradient(colors: [KM.accent, KM.accent.opacity(0.8)], startPoint: .leading, endPoint: .trailing))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
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
                .background(KM.bg)
                .scrollContentBackground(.hidden)
            }
        }
        .background(KM.bg)
    }

    private var emptySnippetsState: some View {
        KMEmptyState(
            icon: "text.badge.plus",
            title: "No snippets yet",
            message: "Great for addresses, email sign-offs, and boilerplate. "
                + "Add terms like ‘my intro’ or ‘my upi id’ to expand them while dictating."
        ) {
            KMGhostButton(label: "Add suggested", icon: "plus") {
                for suggestion in SnippetEngine.suggestedSnippets {
                    let snippet = VoiceSnippet(trigger: suggestion.trigger, replacement: suggestion.placeholder)
                    appState.snippetEngine.addSnippet(snippet)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .background(KM.bg)
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
                    .background(KM.surfaceHi)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).stroke(KM.outline, lineWidth: 1))
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
                        .foregroundColor(KM.onSurface)
                    Text("FlowKeys automatically learns proper nouns and complex words you use often.")
                        .font(.body)
                        .foregroundColor(KM.muted)
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
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(KM.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(KM.accent.opacity(0.12))
                .clipShape(Capsule())
                .buttonStyle(.plain)
            }
            .padding()
            .background(KM.surface)
            
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
                .background(KM.bg)
                .scrollContentBackground(.hidden)
            }
        }
        .background(KM.bg)
    }

    private func addTerm() {
        appState.personalDictionary.addTerm(newTerm)
        newTerm = ""
    }
    
    private var emptyDictionaryState: some View {
        KMEmptyState(
            icon: "character.book.closed",
            title: "No custom words yet",
            message: "Add names, brands, and technical terms FlowKeys keeps getting wrong — "
                + "or just speak naturally and it learns terms you use 3+ times."
        )
        .frame(maxWidth: .infinity)
        .background(KM.bg)
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
        case .manual:     return KM.accent
        case .autoLearned: return KM.green
        case .suggested:  return KM.salmon
        }
    }
}
