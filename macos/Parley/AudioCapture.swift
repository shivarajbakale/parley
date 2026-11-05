import AVFoundation
import Foundation

/// Microphone capture with AVAudioEngine, written as 16 kHz mono AAC in an
/// .m4a — what Whisper and Deepgram want, at a fraction of the bytes of the
/// device's native 48 kHz. The mic is only open between `start` and
/// `stop`/`discard`, so the menu-bar mic indicator is lit only while held.
@MainActor
final class AudioCapture {
    struct Take {
        let url: URL
        let durationMs: Double
    }

    private var engine: AVAudioEngine?
    private var writer: TakeWriter?
    private var startedAt: Date?

    /// 0…1, roughly 30 times a second while recording.
    var onLevel: (Float) -> Void = { _ in }

    var isRecording: Bool { engine != nil }

    func start() throws {
        guard engine == nil else { return }
        let audioEngine = AVAudioEngine()
        let input = audioEngine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw CaptureError.noInput
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("parley-\(UUID().uuidString).m4a")
        let writer = try TakeWriter(url: url, inputFormat: inputFormat) { [weak self] level in
            DispatchQueue.main.async {
                MainActor.assumeIsolated { self?.onLevel(level) }
            }
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { buffer, _ in
            writer.write(buffer)
        }
        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            input.removeTap(onBus: 0)
            writer.finish()
            try? FileManager.default.removeItem(at: url)
            throw error
        }
        engine = audioEngine
        self.writer = writer
        startedAt = Date()
    }

    /// The finished take, or nil when nothing was recording.
    func stop() -> Take? {
        guard let engine, let writer, let startedAt else { return nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        writer.finish()
        self.engine = nil
        self.writer = nil
        self.startedAt = nil
        guard writer.framesWritten > 0 else {
            try? FileManager.default.removeItem(at: writer.url)
            return nil
        }
        return Take(url: writer.url, durationMs: Date().timeIntervalSince(startedAt) * 1000)
    }

    func discard() {
        if let take = stop() { try? FileManager.default.removeItem(at: take.url) }
    }

    enum CaptureError: LocalizedError {
        case noInput
        var errorDescription: String? { "No microphone input is available." }
    }
}

/// Lives on the audio thread between `installTap` and `removeTap`; the main
/// actor touches it only after the tap is gone.
private final class TakeWriter: @unchecked Sendable {
    static let sampleRate: Double = 16_000

    let url: URL
    private let file: AVAudioFile
    private let converter: AVAudioConverter
    private let outputFormat: AVAudioFormat
    private let onLevel: (Float) -> Void
    private var lastLevelAt: UInt64 = 0
    private(set) var framesWritten: AVAudioFramePosition = 0

    init(url: URL, inputFormat: AVAudioFormat, onLevel: @escaping (Float) -> Void) throws {
        guard let output = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: output) else {
            throw AudioCapture.CaptureError.noInput
        }
        self.url = url
        self.outputFormat = output
        self.converter = converter
        self.onLevel = onLevel
        self.file = try AVAudioFile(
            forWriting: url,
            settings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: Self.sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 32_000,
            ],
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func write(_ buffer: AVAudioPCMBuffer) {
        let ratio = Self.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 32
        guard let converted = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }
        var fed = false
        var error: NSError?
        converter.convert(to: converted, error: &error) { _, status in
            if fed {
                status.pointee = .noDataNow
                return nil
            }
            fed = true
            status.pointee = .haveData
            return buffer
        }
        guard error == nil, converted.frameLength > 0 else { return }
        do {
            try file.write(from: converted)
            framesWritten += AVAudioFramePosition(converted.frameLength)
        } catch {
            return
        }
        reportLevel(converted)
    }

    func finish() {
        file.close()
    }

    private func reportLevel(_ buffer: AVAudioPCMBuffer) {
        let now = DispatchTime.now().uptimeNanoseconds
        guard now - lastLevelAt > 33_000_000, let samples = buffer.floatChannelData?[0] else { return }
        lastLevelAt = now
        var sum: Float = 0
        let count = Int(buffer.frameLength)
        for index in 0..<count { sum += samples[index] * samples[index] }
        let rms = (sum / Float(max(count, 1))).squareRoot()
        // Speech sits around -40…-10 dBFS; map that range onto 0…1.
        let db = 20 * log10(max(rms, 0.000_01))
        onLevel(min(max((db + 50) / 40, 0), 1))
    }
}
