// ============================================================
// FILE: Sources/CommandModeService.swift
// FlowKeys — Command Mode (Phase 5)
//
// "Select text anywhere → speak an instruction → the selection is rewritten
// in place." Reuses the existing provider adapters in PostProcessingService
// via a dedicated, tightly-constrained rewrite prompt.
// ============================================================

import Foundation
import ApplicationServices
import AppKit
import os.log

private let cmdLog = OSLog(subsystem: "com.flowkeys.app", category: "CommandMode")

enum CommandModeError: LocalizedError {
    case noSelection
    case emptyInstruction
    case rewriteFailed(String)

    var errorDescription: String? {
        switch self {
        case .noSelection:        return "Select some text first, then start Command Mode."
        case .emptyInstruction:   return "No instruction heard — try again."
        case .rewriteFailed(let m): return "Rewrite failed: \(m)"
        }
    }
}

enum CommandModeSelection {
    /// Best-effort read of the frontmost app's currently selected text via AX.
    static func currentSelectedText() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appEl = AXUIElementCreateApplication(app.processIdentifier)

        func string(_ el: AXUIElement, _ attr: CFString) -> String? {
            var v: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, attr, &v) == .success,
                  let s = v as? String else { return nil }
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        func element(_ el: AXUIElement, _ attr: CFString) -> AXUIElement? {
            var v: CFTypeRef?
            guard AXUIElementCopyAttributeValue(el, attr, &v) == .success,
                  let raw = v, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
            return (raw as! AXUIElement)
        }

        if let focused = element(appEl, kAXFocusedUIElementAttribute as CFString),
           let sel = string(focused, kAXSelectedTextAttribute as CFString) {
            return sel
        }
        return string(appEl, kAXSelectedTextAttribute as CFString)
    }
}

final class CommandModeService {

    private let provider: TranscriptionProvider
    private let keyStore: APIKeyStore
    private let timeout: TimeInterval = 30

    private static let systemPrompt = """
You are an in-place text editor. You are given SELECTED_TEXT and a spoken
INSTRUCTION. Apply the instruction to the selected text and return ONLY the
resulting text — no preamble, no quotes, no explanation, no markdown fences.

Rules:
- Do exactly what the instruction asks. Common instructions: make shorter /
  longer, fix grammar, change tone, translate to <language>, turn into bullet
  points, rephrase, summarize.
- If the instruction says "translate to X", output only the translation in X.
- Preserve the meaning, names, numbers, URLs, code identifiers and formatting
  intent unless the instruction explicitly changes them.
- Preserve the original language unless the instruction says to translate.
- If the instruction is unclear or empty, return SELECTED_TEXT unchanged.
"""

    init(provider: TranscriptionProvider, keyStore: APIKeyStore) {
        self.provider = provider
        self.keyStore = keyStore
    }

    func rewrite(selectedText: String, instruction: String) async throws -> String {
        let selected = selectedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let inst = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !selected.isEmpty else { throw CommandModeError.noSelection }
        guard !inst.isEmpty else { throw CommandModeError.emptyInstruction }

        let user = """
INSTRUCTION: "\(inst)"

SELECTED_TEXT:
\(selected)
"""

        os_log(.info, log: cmdLog, "rewrite: %d chars, instruction=%{public}@",
               selected.count, inst)

        let out: String
        switch provider {
        case .groq, .openai, .grok:
            out = try await runOpenAICompatible(system: Self.systemPrompt, user: user)
        case .gemini:
            out = try await runGemini(system: Self.systemPrompt, user: user)
        case .claude:
            out = try await runClaude(system: Self.systemPrompt, user: user)
        }

        var cleaned = out.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.hasPrefix("\"") && cleaned.hasSuffix("\"") && cleaned.count > 1 {
            cleaned = String(cleaned.dropFirst().dropLast())
        }
        guard !cleaned.isEmpty else { throw CommandModeError.rewriteFailed("empty result") }
        return cleaned
    }

    // MARK: - Provider transports (mirror PostProcessingService)

    private func key(for p: TranscriptionProvider) throws -> String {
        guard let k = keyStore.getKey(for: p), !k.trimmingCharacters(in: .whitespaces).isEmpty else {
            throw CommandModeError.rewriteFailed("\(p.displayName) API key missing")
        }
        return k
    }

    private func runOpenAICompatible(system: String, user: String) async throws -> String {
        let k = try key(for: provider)
        guard let url = URL(string: provider.llmEndpoint) else {
            throw CommandModeError.rewriteFailed("bad endpoint")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("Bearer \(k)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": provider.llmModel,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user],
            ],
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw CommandModeError.rewriteFailed(Self.errText(data))
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = json?["choices"] as? [[String: Any]]
        let msg = choices?.first?["message"] as? [String: Any]
        return msg?["content"] as? String ?? ""
    }

    private func runGemini(system: String, user: String) async throws -> String {
        let k = try key(for: .gemini)
        guard var comps = URLComponents(string: provider.llmEndpoint) else {
            throw CommandModeError.rewriteFailed("bad endpoint")
        }
        comps.queryItems = [URLQueryItem(name: "key", value: k)]
        guard let url = comps.url else { throw CommandModeError.rewriteFailed("bad endpoint") }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "systemInstruction": ["parts": [["text": system]]],
            "contents": [["parts": [["text": user]]]],
            "generationConfig": ["temperature": 0.2],
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw CommandModeError.rewriteFailed(Self.errText(data))
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let cands = json?["candidates"] as? [[String: Any]]
        let content = cands?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        return parts?.compactMap { $0["text"] as? String }.joined() ?? ""
    }

    private func runClaude(system: String, user: String) async throws -> String {
        let k = try key(for: .claude)
        guard let url = URL(string: provider.llmEndpoint) else {
            throw CommandModeError.rewriteFailed("bad endpoint")
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.timeoutInterval = timeout
        req.setValue(k, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": provider.llmModel,
            "max_tokens": 2048,
            "temperature": 0.2,
            "system": system,
            "messages": [["role": "user", "content": user]],
        ])
        let (data, resp) = try await URLSession.shared.data(for: req)
        guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
            throw CommandModeError.rewriteFailed(Self.errText(data))
        }
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let content = json?["content"] as? [[String: Any]]
        return content?
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined() ?? ""
    }

    private static func errText(_ data: Data) -> String {
        if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let e = j["error"] as? [String: Any], let m = e["message"] as? String {
            return m
        }
        return "request failed"
    }
}
