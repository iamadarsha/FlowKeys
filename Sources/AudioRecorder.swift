import AVFoundation
import CoreAudio
import Foundation
import os.log

private let recordingLog = OSLog(subsystem: "com.flowkeys.app", category: "Recording")

struct AudioDevice: Identifiable {
    let id: AudioDeviceID
    let uid: String
    let name: String

    static func availableInputDevices() -> [AudioDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0, nil,
            &dataSize,
            &deviceIDs
        )
        guard status == noErr else { return [] }

        var devices: [AudioDevice] = []
        for deviceID in deviceIDs {
            // Check if device has input streams
            var inputStreamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreamConfiguration,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(deviceID, &inputStreamAddress, 0, nil, &streamSize) == noErr,
                  streamSize > 0 else { continue }

            let bufferListRaw = UnsafeMutableRawPointer.allocate(
                byteCount: Int(streamSize),
                alignment: MemoryLayout<AudioBufferList>.alignment
            )
            defer { bufferListRaw.deallocate() }
            let bufferListPointer = bufferListRaw.bindMemory(to: AudioBufferList.self, capacity: 1)
            guard AudioObjectGetPropertyData(deviceID, &inputStreamAddress, 0, nil, &streamSize, bufferListPointer) == noErr else { continue }

            let bufferList = UnsafeMutableAudioBufferListPointer(bufferListPointer)
            let inputChannels = bufferList.reduce(0) { $0 + Int($1.mNumberChannels) }
            guard inputChannels > 0 else { continue }

            // Get device UID
            var uidAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceUID,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var uidSize = UInt32(MemoryLayout<CFString?>.size)
            let uidRaw = UnsafeMutableRawPointer.allocate(
                byteCount: Int(uidSize),
                alignment: MemoryLayout<CFString?>.alignment
            )
            defer { uidRaw.deallocate() }
            guard AudioObjectGetPropertyData(deviceID, &uidAddress, 0, nil, &uidSize, uidRaw) == noErr else { continue }
            guard let uidRef = uidRaw.load(as: CFString?.self) else { continue }
            let uid = uidRef as String
            guard !uid.isEmpty else { continue }

            // Get device name
            var nameAddress = AudioObjectPropertyAddress(
                mSelector: kAudioObjectPropertyName,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var nameSize = UInt32(MemoryLayout<CFString?>.size)
            let nameRaw = UnsafeMutableRawPointer.allocate(
                byteCount: Int(nameSize),
                alignment: MemoryLayout<CFString?>.alignment
            )
            defer { nameRaw.deallocate() }
            guard AudioObjectGetPropertyData(deviceID, &nameAddress, 0, nil, &nameSize, nameRaw) == noErr else { continue }
            guard let nameRef = nameRaw.load(as: CFString?.self) else { continue }
            let name = nameRef as String
            guard !name.isEmpty else { continue }

            devices.append(AudioDevice(id: deviceID, uid: uid, name: name))
        }
        return devices
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        // Look up through the enumerated devices to avoid CFString pointer issues
        return availableInputDevices().first(where: { $0.uid == uid })?.id
    }
}

enum AudioRecorderError: LocalizedError {
    case invalidInputFormat(String)
    case missingInputDevice
    case recoveryExhausted

    var errorDescription: String? {
        switch self {
        case .invalidInputFormat(let details):
            return "Invalid input format: \(details)"
        case .missingInputDevice:
            return "No audio input device available."
        case .recoveryExhausted:
            return "Lost the microphone connection and couldn't recover it automatically."
        }
    }
}

class AudioRecorder: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private var tempFileURL: URL?
    private let audioFileQueue = DispatchQueue(label: "com.flowkeys.app.audiofile")
    private var recordingStartTime: CFAbsoluteTime = 0
    private var firstBufferLogged = false
    private let _bufferCount = OSAllocatedUnfairLock(initialState: 0)
    private var currentDeviceUID: String?
    private var storedInputFormat: AVAudioFormat?

    private var configChangeObserver: NSObjectProtocol?
    private var watchdogTimer: DispatchSourceTimer?
    private var rebuildAttempt = 0
    private static let maxRebuildAttempts = 2
    private static let watchdogTimeout: TimeInterval = 2.0

    /// Owns every mutation of `audioEngine`/`storedInputFormat`/`currentDeviceUID`/
    /// `rebuildAttempt`/`watchdogTimer` — config-change recovery and watchdog-triggered
    /// rebuilds both hop onto this queue instead of racing each other or the caller
    /// of `startRecording`/`stopRecording` directly.
    private let engineLifecycleQueue = DispatchQueue(label: "com.flowkeys.app.enginelifecycle")

    @Published var isRecording = false
    /// Thread-safe flag read from the audio tap callback.
    private let _recording = OSAllocatedUnfairLock(initialState: false)
    @Published var audioLevel: Float = 0.0
    private var smoothedLevel: Float = 0.0

    /// Called on the audio thread when the first non-silent buffer arrives.
    var onRecordingReady: (() -> Void)?
    private var readyFired = false

    /// Fired at most once per recording session when recovery is exhausted or a
    /// rebuild attempt fails outright — lets `AppState` learn about a failure the
    /// watchdog/config-change path discovers well after `startRecording()` returned.
    /// Bumped once per `startRecording()` call and re-checked at delivery time (on
    /// main, after the `DispatchQueue.main.async` hop) so a failure from an old
    /// session that the caller has already retried/superseded can never reach
    /// `AppState` and tear down a live, newer session.
    var onRecordingFailure: ((Error) -> Void)?
    private var failureReported = false
    private let _generation = OSAllocatedUnfairLock(initialState: 0)

    private func reportFailureOnce(_ error: Error, generation: Int) {
        guard !failureReported else { return }
        failureReported = true
        let callback = onRecordingFailure
        let generationLock = _generation
        DispatchQueue.main.async {
            guard generationLock.withLock({ $0 }) == generation else { return }
            callback?(error)
        }
    }

    override init() {
        super.init()
        configChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.handleEngineConfigChange(notification)
        }
    }

    deinit {
        if let observer = configChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        cancelWatchdog()
    }

    // MARK: - Engine lifecycle

    private func invalidateEngine() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        storedInputFormat = nil
    }

    private func buildAndStartEngine(deviceUID: String?) throws {
        invalidateEngine()

        let t0 = CFAbsoluteTimeGetCurrent()
        let engine = AVAudioEngine()
        os_log(.info, log: recordingLog, "AVAudioEngine created: %.3fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)

        // Set specific input device if requested
        if let uid = deviceUID, !uid.isEmpty, uid != "default",
           let deviceID = AudioDevice.deviceID(forUID: uid) {
            os_log(.info, log: recordingLog, "device lookup resolved to %d: %.3fms", deviceID, (CFAbsoluteTimeGetCurrent() - t0) * 1000)
            let inputUnit = engine.inputNode.audioUnit!
            var id = deviceID
            AudioUnitSetProperty(
                inputUnit,
                kAudioOutputUnitProperty_CurrentDevice,
                kAudioUnitScope_Global,
                0,
                &id,
                UInt32(MemoryLayout<AudioDeviceID>.size)
            )
        }

        let inputNode = engine.inputNode
        os_log(.info, log: recordingLog, "inputNode accessed: %.3fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)
        let inputFormat = inputNode.outputFormat(forBus: 0)
        os_log(.info, log: recordingLog, "inputFormat retrieved (rate=%.0f, ch=%d): %.3fms", inputFormat.sampleRate, inputFormat.channelCount, (CFAbsoluteTimeGetCurrent() - t0) * 1000)
        guard inputFormat.sampleRate > 0 else {
            throw AudioRecorderError.invalidInputFormat("Invalid sample rate: \(inputFormat.sampleRate)")
        }
        guard inputFormat.channelCount > 0 else {
            throw AudioRecorderError.invalidInputFormat("No input channels available")
        }

        storedInputFormat = inputFormat
        _bufferCount.withLock { $0 = 0 }
        readyFired = false

        // Install tap — checks isRecording and audioFile dynamically
        inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            guard let self, self._recording.withLock({ $0 }) else { return }

            let count = self._bufferCount.withLock { val -> Int in
                val += 1
                return val
            }

            // Check if this buffer has real audio
            var rms: Float = 0
            let frames = Int(buffer.frameLength)
            if frames > 0, let channelData = buffer.floatChannelData {
                let samples = channelData[0]
                var sum: Float = 0
                for i in 0..<frames { sum += samples[i] * samples[i] }
                rms = sqrtf(sum / Float(frames))
            }

            if count <= 40 {
                let elapsed = (CFAbsoluteTimeGetCurrent() - self.recordingStartTime) * 1000
                os_log(.info, log: recordingLog, "buffer #%d at %.3fms, frames=%d, rms=%.6f", count, elapsed, buffer.frameLength, rms)
            }

            // Fire ready callback on first non-silent buffer
            if !self.readyFired && rms > 0 {
                self.readyFired = true
                let elapsed = (CFAbsoluteTimeGetCurrent() - self.recordingStartTime) * 1000
                os_log(.info, log: recordingLog, "FIRST non-silent buffer at %.3fms — recording ready", elapsed)
                self.onRecordingReady?()
            }

            self.audioFileQueue.sync {
                if let file = self.audioFile {
                    do {
                        try file.write(from: buffer)
                    } catch {
                        self.audioFile = nil
                    }
                }
            }
            self.computeAudioLevel(from: buffer)
        }
        os_log(.info, log: recordingLog, "tap installed: %.3fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)

        engine.prepare()
        os_log(.info, log: recordingLog, "engine prepared: %.3fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)

        self.audioEngine = engine
        self.currentDeviceUID = deviceUID

        try engine.start()
        os_log(.info, log: recordingLog, "engine started: %.3fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)
    }

    // MARK: - Configuration change handling

    /// `AVAudioEngineConfigurationChange` is delivered on an internal AVAudioEngine
    /// dispatch queue; Apple's docs warn that synchronous engine teardown/rebuild
    /// inside this callback can deadlock. Return immediately and hand recovery off
    /// to `engineLifecycleQueue`, which also serializes it against watchdog-triggered
    /// rebuilds and `startRecording`/`stopRecording` so they can never race.
    private func handleEngineConfigChange(_ notification: Notification) {
        guard let engine = notification.object as? AVAudioEngine else { return }
        engineLifecycleQueue.async { [weak self] in
            guard let self, engine === self.audioEngine else { return }
            os_log(.info, log: recordingLog, "AVAudioEngineConfigurationChange — invalidating engine")
            self.invalidateEngine()

            if self._recording.withLock({ $0 }) {
                os_log(.info, log: recordingLog, "was recording — attempting transparent restart")
                self.restartRecordingLocked()
            }
        }
    }

    /// Must only be called while already running on `engineLifecycleQueue`.
    private func restartRecordingLocked() {
        let myGeneration = _generation.withLock { $0 }
        rebuildAttempt += 1
        if rebuildAttempt > Self.maxRebuildAttempts {
            os_log(.error, log: recordingLog, "exceeded max rebuild attempts (%d) — giving up", Self.maxRebuildAttempts)
            _recording.withLock { $0 = false }
            DispatchQueue.main.async { self.isRecording = false }
            reportFailureOnce(AudioRecorderError.recoveryExhausted, generation: myGeneration)
            return
        }

        // On second attempt, fall back to system default device
        let deviceToUse: String?
        if rebuildAttempt >= Self.maxRebuildAttempts {
            os_log(.info, log: recordingLog, "rebuild attempt %d — falling back to system default device", rebuildAttempt)
            deviceToUse = nil
        } else {
            deviceToUse = currentDeviceUID
        }

        do {
            try buildAndStartEngine(deviceUID: deviceToUse)
            startBufferWatchdogLocked()
            os_log(.info, log: recordingLog, "transparent restart succeeded (attempt %d)", rebuildAttempt)
        } catch {
            os_log(.error, log: recordingLog, "transparent restart failed: %{public}@", error.localizedDescription)
            _recording.withLock { $0 = false }
            DispatchQueue.main.async { self.isRecording = false }
            reportFailureOnce(error, generation: myGeneration)
        }
    }

    // MARK: - Buffer watchdog

    /// Must only be called while already running on `engineLifecycleQueue`.
    private func startBufferWatchdogLocked() {
        cancelWatchdog()
        let timer = DispatchSource.makeTimerSource(queue: .global(qos: .userInitiated))
        timer.schedule(deadline: .now() + Self.watchdogTimeout)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            // Hand the actual rebuild decision to the lifecycle queue — this timer
            // fires on a plain global queue and must not touch engine state directly.
            self.engineLifecycleQueue.async {
                guard self._recording.withLock({ $0 }) else { return }

                let count = self._bufferCount.withLock { $0 }
                if count == 0 {
                    os_log(.error, log: recordingLog,
                           "watchdog: 0 buffers after %.1fs (attempt %d) — rebuilding engine",
                           Self.watchdogTimeout, self.rebuildAttempt)
                    self.restartRecordingLocked()
                } else {
                    os_log(.info, log: recordingLog, "watchdog: %d buffers after %.1fs — healthy, resetting rebuild counter", count, Self.watchdogTimeout)
                    self.rebuildAttempt = 0
                }
            }
        }
        timer.resume()
        watchdogTimer = timer
    }

    private func cancelWatchdog() {
        watchdogTimer?.cancel()
        watchdogTimer = nil
    }

    // MARK: - Public API

    func startRecording(deviceUID: String? = nil) throws {
        let t0 = CFAbsoluteTimeGetCurrent()
        recordingStartTime = t0
        firstBufferLogged = false
        _bufferCount.withLock { $0 = 0 }
        readyFired = false
        _generation.withLock { $0 += 1 }

        os_log(.info, log: recordingLog, "startRecording() entered")

        guard AVCaptureDevice.default(for: .audio) != nil else {
            throw AudioRecorderError.missingInputDevice
        }
        os_log(.info, log: recordingLog, "AVCaptureDevice check: %.3fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)

        // Engine build, marking ourselves as recording, and starting the watchdog
        // all happen in ONE atomic block — otherwise a config-change notification
        // landing between "engine built" and "_recording = true" would see
        // `_recording == false`, invalidate the engine, and skip the restart path
        // entirely (since nothing looks like it's recording yet), leaving the tap
        // torn down until the watchdog eventually notices and burns a rebuild
        // attempt to fix it.
        try engineLifecycleQueue.sync {
            // `rebuildAttempt`/`failureReported` are only ever otherwise touched
            // from this queue (`restartRecordingLocked`/`reportFailureOnce`) —
            // reset them here too instead of on the caller's thread so there's no
            // unsynchronized cross-queue access to either.
            rebuildAttempt = 0
            failureReported = false

            let engineNeedsRebuild = audioEngine == nil || currentDeviceUID != deviceUID || !(audioEngine?.isRunning ?? false)

            if engineNeedsRebuild {
                try buildAndStartEngine(deviceUID: deviceUID)
            } else if let engine = audioEngine, !engine.isRunning {
                try engine.start()
                os_log(.info, log: recordingLog, "engine restarted: %.3fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)
            }
            _recording.withLock { $0 = true }
            startBufferWatchdogLocked()
        }
        DispatchQueue.main.async { self.isRecording = true }

        guard let inputFormat = storedInputFormat else {
            throw AudioRecorderError.invalidInputFormat("No stored input format")
        }

        // Create a temp file to write audio to
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(UUID().uuidString + ".wav")
        self.tempFileURL = fileURL

        // Try the input format first to avoid conversion issues, then fall back to 16-bit PCM.
        let newAudioFile: AVAudioFile
        do {
            newAudioFile = try AVAudioFile(forWriting: fileURL, settings: inputFormat.settings)
        } catch {
            let fallbackSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: inputFormat.sampleRate,
                AVNumberOfChannelsKey: inputFormat.channelCount,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: inputFormat.isInterleaved ? 0 : 1,
            ]
            newAudioFile = try AVAudioFile(
                forWriting: fileURL,
                settings: fallbackSettings,
                commonFormat: .pcmFormatInt16,
                interleaved: inputFormat.isInterleaved
            )
        }
        os_log(.info, log: recordingLog, "audio file created: %.3fms", (CFAbsoluteTimeGetCurrent() - t0) * 1000)

        audioFileQueue.sync { self.audioFile = newAudioFile }

        os_log(.info, log: recordingLog, "startRecording() complete: %.3fms total", (CFAbsoluteTimeGetCurrent() - t0) * 1000)
    }

    func stopRecording() -> URL? {
        let count = _bufferCount.withLock { $0 }
        let elapsed = (CFAbsoluteTimeGetCurrent() - recordingStartTime) * 1000
        os_log(.info, log: recordingLog, "stopRecording() called: %.3fms after start, %d buffers received", elapsed, count)

        audioFileQueue.sync { audioFile = nil }
        isRecording = false
        smoothedLevel = 0.0
        DispatchQueue.main.async { self.audioLevel = 0.0 }

        // `_recording = false` happens INSIDE the same lifecycle-queue turn as
        // cancelling the watchdog and stopping the engine — otherwise a watchdog
        // check already in flight on this queue could read a stale `_recording ==
        // true` (set moments before this queue turn runs) and restart the engine
        // right after the user pressed stop. Stop the engine (not tear it down) so
        // the mic indicator goes away while keeping the engine object for a fast
        // restart.
        engineLifecycleQueue.sync {
            _recording.withLock { $0 = false }
            cancelWatchdog()
            audioEngine?.stop()
        }
        os_log(.info, log: recordingLog, "engine stopped (mic indicator off)")

        return tempFileURL
    }

    private func computeAudioLevel(from buffer: AVAudioPCMBuffer) {
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return }

        var sumOfSquares: Float = 0.0
        if let channelData = buffer.floatChannelData {
            let samples = channelData[0]
            for i in 0..<frames {
                let sample = samples[i]
                sumOfSquares += sample * sample
            }
        } else if let channelData = buffer.int16ChannelData {
            let samples = channelData[0]
            for i in 0..<frames {
                let sample = Float(samples[i]) / Float(Int16.max)
                sumOfSquares += sample * sample
            }
        } else {
            return
        }

        let rms = sqrtf(sumOfSquares / Float(frames))

        // Scale RMS (~0.01-0.1 for speech) to 0-1 range
        let scaled = min(rms * 10.0, 1.0)

        // Fast attack, slower release — follows speech dynamics closely
        if scaled > smoothedLevel {
            smoothedLevel = smoothedLevel * 0.3 + scaled * 0.7
        } else {
            smoothedLevel = smoothedLevel * 0.6 + scaled * 0.4
        }

        DispatchQueue.main.async {
            self.audioLevel = self.smoothedLevel
        }
    }

    func cleanup() {
        if let url = tempFileURL {
            try? FileManager.default.removeItem(at: url)
            tempFileURL = nil
        }
    }
}
