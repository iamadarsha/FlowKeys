// ============================================================
// FILE: Sources/LocalAI/LocalModelManager.swift
// FlowKeys — Local AI (Phase 2)
//
// Downloads, verifies, stores, and deletes on-device model files.
// No model weights ship in the app bundle; everything lands in
//   ~/Library/Application Support/FlowKeys/Models/
//
// Guarantees (requirements/UNIFIED_UPGRADE_PLAN.md §3.8):
//   - HTTPS only, host allow-listed (LocalModelManifest.isAllowed)
//   - expected byte size + SHA-256 verified before "installed"
//   - download to a temp ".part" file, atomic rename on success
//   - free-space check before starting
//   - resumable via HTTP Range, cancellable
// ============================================================

import Foundation
import Combine
import os.log

private let modelLog = OSLog(subsystem: "com.flowkeys.app", category: "LocalModel")

enum LocalModelError: LocalizedError {
    case disallowedHost(String)
    case insufficientDiskSpace(neededBytes: Int64, freeBytes: Int64)
    case httpStatus(Int)
    case sizeMismatch(expected: Int64, got: Int64)
    case checksumMismatch(expected: String, got: String)
    case notPinned
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .disallowedHost(let h): return "Refusing to download from an unexpected host: \(h)"
        case .insufficientDiskSpace(let need, let free):
            return "Not enough disk space — need \(ByteCountFormatter.string(fromByteCount: need, countStyle: .file)), "
                 + "\(ByteCountFormatter.string(fromByteCount: free, countStyle: .file)) free."
        case .httpStatus(let c): return "Download failed (HTTP \(c))."
        case .sizeMismatch(let e, let g): return "Downloaded file is the wrong size (expected \(e), got \(g))."
        case .checksumMismatch: return "Downloaded file failed its integrity check. Try again."
        case .notPinned: return "This model has no pinned checksum yet and cannot be used."
        case .writeFailed(let m): return "Could not save the model file: \(m)"
        }
    }
}

enum LocalModelStatus: Equatable {
    case notInstalled
    case downloading(progress: Double, receivedBytes: Int64, totalBytes: Int64)
    case verifying
    case installed
    case failed(String)
    case incompatible(reason: String)
}

/// Not `@MainActor` so `AppState` (nonisolated) can own one directly.
/// Every `@Published` mutation is funnelled onto the main thread via `setStatus`.
final class LocalModelManager: ObservableObject, @unchecked Sendable {

    @Published private(set) var statuses: [String: LocalModelStatus] = [:]

    private let fileManager = FileManager.default
    private let tasks = OSAllocatedUnfairLock(initialState: [String: Task<Void, Never>]())

    init() {
        refreshInstalledState()
    }

    private func setStatus(_ status: LocalModelStatus, for id: String) {
        if Thread.isMainThread {
            statuses[id] = status
        } else {
            DispatchQueue.main.async { self.statuses[id] = status }
        }
    }

    // MARK: - Paths

    var storeDirectory: URL { LocalModelManifest.storeDirectory() }

    func localURL(for descriptor: LocalModelDescriptor) -> URL {
        storeDirectory.appendingPathComponent(descriptor.relativeStorePath)
    }

    func isInstalled(_ descriptor: LocalModelDescriptor) -> Bool {
        if case .installed = statuses[descriptor.id] { return true }
        return false
    }

    func installedPath(_ descriptor: LocalModelDescriptor) -> URL? {
        let url = localURL(for: descriptor)
        return (isInstalled(descriptor) && fileManager.fileExists(atPath: url.path)) ? url : nil
    }

    func status(_ id: String) -> LocalModelStatus { statuses[id] ?? .notInstalled }

    // MARK: - Compatibility

    func compatibilityReason(_ d: LocalModelDescriptor) -> String? {
        let ram = ProcessInfo.processInfo.physicalMemory
        let gb = Int(ram / 1_000_000_000)
        if gb > 0 && gb < d.requirements.minRAMGB {
            return "Needs \(d.requirements.minRAMGB) GB RAM"
        }
        #if !arch(arm64)
        if d.requirements.requiresAppleSilicon { return "Needs Apple Silicon" }
        #endif
        return nil
    }

    // MARK: - Installed-state scan

    func refreshInstalledState() {
        for d in LocalModelManifest.all {
            if let reason = compatibilityReason(d) {
                setStatus(.incompatible(reason: reason), for: d.id)
                continue
            }
            let url = localURL(for: d)
            guard fileManager.fileExists(atPath: url.path) else {
                setStatus(.notInstalled, for: d.id)
                continue
            }
            if let size = try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64,
               size == d.expectedByteSize {
                setStatus(.installed, for: d.id)
            } else {
                setStatus(.notInstalled, for: d.id)
            }
        }
    }

    // MARK: - Disk space

    private func freeDiskBytes() -> Int64 {
        let path = storeDirectory.deletingLastPathComponent().path
        if let attrs = try? fileManager.attributesOfFileSystem(forPath: path),
           let free = attrs[.systemFreeSize] as? Int64 {
            return free
        }
        return .max
    }

    // MARK: - Download / delete

    func download(_ descriptor: LocalModelDescriptor) {
        let alreadyRunning = tasks.withLock { $0[descriptor.id] != nil }
        guard !alreadyRunning else { return }

        guard descriptor.checksumSHA256 != nil else {
            setStatus(.failed(LocalModelError.notPinned.localizedDescription), for: descriptor.id)
            return
        }
        if let reason = compatibilityReason(descriptor) {
            setStatus(.incompatible(reason: reason), for: descriptor.id)
            return
        }

        let task = Task { [weak self] in
            guard let self else { return }
            do {
                try await self.performDownload(descriptor)
                self.setStatus(.installed, for: descriptor.id)
            } catch is CancellationError {
                self.setStatus(.notInstalled, for: descriptor.id)
            } catch {
                self.setStatus(.failed(error.localizedDescription), for: descriptor.id)
                os_log(.error, log: modelLog, "download %{public}@ failed: %{public}@",
                       descriptor.id, error.localizedDescription)
            }
            self.tasks.withLock { $0[descriptor.id] = nil }
        }
        tasks.withLock { $0[descriptor.id] = task }
    }

    func cancelDownload(_ id: String) {
        let t = tasks.withLock { dict -> Task<Void, Never>? in
            let existing = dict[id]; dict[id] = nil; return existing
        }
        t?.cancel()
        if case .downloading = statuses[id] { setStatus(.notInstalled, for: id) }
    }

    func delete(_ descriptor: LocalModelDescriptor) throws {
        cancelDownload(descriptor.id)
        let url = localURL(for: descriptor)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        setStatus(.notInstalled, for: descriptor.id)
    }

    private func performDownload(_ d: LocalModelDescriptor) async throws {
        guard LocalModelManifest.isAllowed(d.url) else {
            throw LocalModelError.disallowedHost(d.url.host ?? "unknown")
        }
        let free = freeDiskBytes()
        if free < d.expectedByteSize + 200_000_000 {
            throw LocalModelError.insufficientDiskSpace(neededBytes: d.expectedByteSize, freeBytes: free)
        }

        let dest = localURL(for: d)
        try fileManager.createDirectory(at: dest.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        let partURL = dest.appendingPathExtension("part")

        var resumeFrom: Int64 = 0
        if let attrs = try? fileManager.attributesOfItem(atPath: partURL.path),
           let existing = attrs[.size] as? Int64, existing < d.expectedByteSize, existing > 0 {
            resumeFrom = existing
        } else {
            try? fileManager.removeItem(at: partURL)
        }

        var request = URLRequest(url: d.url)
        request.timeoutInterval = 60
        if resumeFrom > 0 {
            request.setValue("bytes=\(resumeFrom)-", forHTTPHeaderField: "Range")
        }

        setStatus(.downloading(progress: resumeFrom > 0 ? Double(resumeFrom) / Double(d.expectedByteSize) : 0,
                               receivedBytes: resumeFrom, totalBytes: d.expectedByteSize), for: d.id)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw LocalModelError.httpStatus(0) }
        guard http.statusCode == 200 || http.statusCode == 206 else {
            throw LocalModelError.httpStatus(http.statusCode)
        }
        if http.statusCode == 200 {
            resumeFrom = 0
            try? fileManager.removeItem(at: partURL)
        }

        if !fileManager.fileExists(atPath: partURL.path) {
            fileManager.createFile(atPath: partURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: partURL)
        try handle.seekToEnd()

        var received = resumeFrom
        var buffer = Data()
        buffer.reserveCapacity(1_048_576)
        var lastUIUpdate = Date.distantPast

        do {
            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                if buffer.count >= 1_048_576 {
                    try handle.write(contentsOf: buffer)
                    received += Int64(buffer.count)
                    buffer.removeAll(keepingCapacity: true)
                    if Date().timeIntervalSince(lastUIUpdate) > 0.2 {
                        lastUIUpdate = Date()
                        setStatus(.downloading(progress: Double(received) / Double(d.expectedByteSize),
                                               receivedBytes: received, totalBytes: d.expectedByteSize),
                                  for: d.id)
                    }
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
                received += Int64(buffer.count)
            }
            try handle.close()
        } catch {
            try? handle.close()
            throw error
        }

        let finalSize = (try? fileManager.attributesOfItem(atPath: partURL.path)[.size] as? Int64) ?? nil
        guard finalSize == d.expectedByteSize else {
            throw LocalModelError.sizeMismatch(expected: d.expectedByteSize, got: finalSize ?? 0)
        }

        setStatus(.verifying, for: d.id)
        let digest = try CryptoKitSHA256.hex(of: partURL)
        if let expected = d.checksumSHA256, digest.lowercased() != expected.lowercased() {
            try? fileManager.removeItem(at: partURL)
            throw LocalModelError.checksumMismatch(expected: expected, got: digest)
        }

        if fileManager.fileExists(atPath: dest.path) {
            try fileManager.removeItem(at: dest)
        }
        try fileManager.moveItem(at: partURL, to: dest)
        os_log(.info, log: modelLog, "installed model %{public}@ (%lld bytes)", d.id, d.expectedByteSize)
    }
}
