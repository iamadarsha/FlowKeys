// ============================================================
// FILE: Sources/LocalAI/CryptoKitSHA256.swift
// FlowKeys — Local AI (Phase 2)
//
// Streamed SHA-256 of a file (no full-file load into memory), for model
// integrity verification. CryptoKit ships with macOS 13+.
// ============================================================

import Foundation
import CryptoKit

enum CryptoKitSHA256 {

    /// Lowercase hex SHA-256 of the file at `url`, hashed in 1 MiB chunks.
    static func hex(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        let chunkSize = 1_048_576
        while true {
            let chunk = try handle.read(upToCount: chunkSize) ?? Data()
            if chunk.isEmpty { break }
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
