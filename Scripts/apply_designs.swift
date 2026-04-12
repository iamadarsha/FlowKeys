import Foundation

// A generic script to adjust background colors and padding in SettingsView to match the new dark #0D0D0F / #17171A theme
let settingsPath = "Sources/SettingsView.swift"
if let content = try? String(contentsOfFile: settingsPath) {
    var newContent = content.replacingOccurrences(of: "Color(NSColor.textBackgroundColor)", with: "Color(white: 0.09)")
    newContent = newContent.replacingOccurrences(of: "Color(NSColor.windowBackgroundColor)", with: "Color(white: 0.05)")
    // Make sidebar dark
    newContent = newContent.replacingOccurrences(of: ".background(Color(NSColor.controlBackgroundColor))", with: ".background(Color(white: 0.04))")
    try? newContent.write(toFile: settingsPath, atomically: true, encoding: .utf8)
}

let setupPath = "Sources/SetupView.swift"
if let content = try? String(contentsOfFile: setupPath) {
    var newContent = content.replacingOccurrences(of: "Color(NSColor.windowBackgroundColor)", with: "Color(white: 0.05)")
    newContent = newContent.replacingOccurrences(of: "Color(NSColor.controlBackgroundColor)", with: "Color(white: 0.09)")
    try? newContent.write(toFile: setupPath, atomically: true, encoding: .utf8)
}

// Bump Info.plist
let plistPath = "Info.plist"
if let content = try? String(contentsOfFile: plistPath) {
    var newContent = content.replacingOccurrences(of: "<string>1.1.1</string>", with: "<string>1.1.2</string>")
    try? newContent.write(toFile: plistPath, atomically: true, encoding: .utf8)
}
