import Foundation
import os
import ParleyCore

/// Runs the headless TypeScript engine (`engine.mjs` under the bundled Node)
/// as a child process and moves lines across its stdin/stdout. stderr is the
/// engine's log, forwarded to unified logging.
@MainActor
final class EngineProcess {
    private let log = Logger(subsystem: "com.shivarajbakale.parley.mac", category: "engine")
    private var process: Process?
    private var stdin: FileHandle?
    private var stdoutBuffer = LineBuffer()
    private var stderrBuffer = LineBuffer()

    var onLine: (String) -> Void = { _ in }
    var onExit: (Int32) -> Void = { _ in }

    var isRunning: Bool { process?.isRunning ?? false }

    enum LaunchError: LocalizedError {
        case missing(String)
        var errorDescription: String? {
            switch self {
            case .missing(let what): return "The engine is missing from the app (\(what))."
            }
        }
    }

    func start() throws {
        guard let resources = Bundle.main.resourceURL?.appendingPathComponent("engine") else {
            throw LaunchError.missing("Resources")
        }
        let node = resources.appendingPathComponent("node")
        let script = resources.appendingPathComponent("engine.mjs")
        for file in [node, script] where !FileManager.default.fileExists(atPath: file.path) {
            throw LaunchError.missing(file.lastPathComponent)
        }

        let child = Process()
        child.executableURL = node
        child.arguments = [script.path]
        child.environment = ProcessInfo.processInfo.environment

        let input = Pipe()
        let output = Pipe()
        let errors = Pipe()
        child.standardInput = input
        child.standardOutput = output
        child.standardError = errors

        // Pipe callbacks arrive on a background queue; hop to main in order,
        // so frames are handled in the order the engine wrote them.
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    for line in self.stdoutBuffer.append(data) { self.onLine(line) }
                }
            }
        }
        errors.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    for line in self.stderrBuffer.append(data) {
                        self.log.info("\(line, privacy: .public)")
                    }
                }
            }
        }
        child.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            output.fileHandleForReading.readabilityHandler = nil
            errors.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                MainActor.assumeIsolated {
                    guard let self else { return }
                    self.process = nil
                    self.stdin = nil
                    self.stdoutBuffer = LineBuffer()
                    self.stderrBuffer = LineBuffer()
                    self.onExit(status)
                }
            }
        }

        try child.run()
        process = child
        stdin = input.fileHandleForWriting
        log.info("engine started, pid \(child.processIdentifier)")
    }

    func send(_ line: String) {
        guard let stdin else { return }
        do {
            try stdin.write(contentsOf: Data(line.utf8))
        } catch {
            log.error("write to engine failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Closing stdin is the engine's shutdown signal.
    func stop() {
        try? stdin?.close()
        stdin = nil
    }
}
