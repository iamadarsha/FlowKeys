import AppKit
import Foundation

struct AudioFeedbackManager {
    static let shared = AudioFeedbackManager()
    
    func playStartRecording(volume: Float = 1.0) {
        let sound = NSSound(named: "Hero")
        sound?.volume = volume
        sound?.play()
    }
    
    func playStopRecording(volume: Float = 1.0) {
        let sound = NSSound(named: "Ping")
        sound?.volume = volume
        sound?.play()
    }
    
    func playSnippetExpanded(volume: Float = 1.0) {
        let sound = NSSound(named: "Glass")
        sound?.volume = volume
        sound?.play()
    }
    
    func playError(volume: Float = 1.0) {
        let sound = NSSound(named: "Basso")
        sound?.volume = volume
        sound?.play()
    }
}
