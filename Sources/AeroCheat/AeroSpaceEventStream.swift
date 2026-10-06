import AeroCheatCore
import Foundation

/// Runs `aerospace subscribe` as a child process and reports its JSON events.
/// Receive-only: it never runs a state-changing AeroSpace command. Everything is delivered on the main queue.
final class AeroSpaceEventStream {
    enum Status: Equatable {
        case stopped
        case connecting
        case connected
        case notInstalled
        case tooOld(AeroSpaceVersion)
        case notRunning
    }

    var onEvent: ((AeroEvent) -> Void)?
    var onStatus: ((Status) -> Void)?

    private(set) var status: Status = .stopped {
        didSet { if status != oldValue { onStatus?(status) } }
    }

    /// Bumped on every start/stop so callbacks of an earlier child are ignored.
    private var generation = 0
    private var process: Process?
    private var retry: DispatchWorkItem?
    private var failures = 0
    private static let backoff: [TimeInterval] = [1, 2, 4, 8, 15, 30]

    func start() {
        guard status == .stopped else { return }
        generation += 1
        failures = 0
        status = .connecting
        attempt(generation)
    }

    func stop() {
        generation += 1
        retry?.cancel()
        retry = nil
        if let process, process.isRunning { process.terminate() }
        process = nil
        status = .stopped
    }

    private func attempt(_ gen: Int) {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let binary = Self.locateBinary()
            let version = binary.flatMap(Self.readVersion)
            DispatchQueue.main.async {
                guard let self, self.generation == gen else { return }
                guard let binary else {
                    self.status = .notInstalled
                    return self.scheduleRetry(gen)
                }
                if let version, version < AeroSpaceVersion.minimumForSubscribe {
                    self.status = .tooOld(version)
                    return self.scheduleRetry(gen)
                }
                self.spawn(binary, gen)
            }
        }
    }

    private func spawn(_ binary: String, _ gen: Int) {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: binary)
        child.arguments = ["subscribe", "--no-send-initial", "focus-changed", "focused-workspace-changed", "binding-triggered", "mode-changed"]
        child.standardInput = FileHandle.nullDevice
        let out = Pipe()
        let err = Pipe()
        child.standardOutput = out
        child.standardError = err

        var buffer = LineBuffer()
        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if data.isEmpty { handle.readabilityHandler = nil; return }
            let events = buffer.append(data).compactMap { AeroEvent.parse(line: $0) }
            guard !events.isEmpty else { return }
            DispatchQueue.main.async {
                guard let self, self.generation == gen else { return }
                events.forEach { self.onEvent?($0) }
            }
        }

        let startedAt = Date()
        child.terminationHandler = { [weak self] finished in
            out.fileHandleForReading.readabilityHandler = nil
            let message = String(decoding: err.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            DispatchQueue.main.async {
                guard let self, self.generation == gen else { return }
                self.process = nil
                // Dying right away means the server is not answering; a later exit is a dropped subscription.
                let quick = Date().timeIntervalSince(startedAt) < 2
                NSLog("AeroCheat: aerospace subscribe exited (status \(finished.terminationStatus))\(message.isEmpty ? "" : ": \(message)")")
                if quick { self.status = .notRunning } else { self.failures = 0; self.status = .connecting }
                self.scheduleRetry(gen)
            }
        }

        do {
            try child.run()
        } catch {
            NSLog("AeroCheat: cannot launch \(binary): \(error)")
            status = .notRunning
            return scheduleRetry(gen)
        }
        process = child
        // Still alive shortly after launch: the server accepted the subscription.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            guard let self, self.generation == gen, self.process === child, child.isRunning else { return }
            self.failures = 0
            self.status = .connected
        }
    }

    private func scheduleRetry(_ gen: Int) {
        let delay = Self.backoff[min(failures, Self.backoff.count - 1)]
        failures += 1
        let work = DispatchWorkItem { [weak self] in
            guard let self, self.generation == gen else { return }
            self.attempt(gen)
        }
        retry = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private static func locateBinary() -> String? {
        AeroSpaceBinary.candidates(path: ProcessInfo.processInfo.environment["PATH"])
            .first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// `aerospace --version` is read-only. Returns `nil` when the output cannot be read.
    private static func readVersion(of binary: String) -> AeroSpaceVersion? {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: binary)
        child.arguments = ["--version"]
        let out = Pipe()
        child.standardOutput = out
        child.standardError = FileHandle.nullDevice
        child.standardInput = FileHandle.nullDevice
        do { try child.run() } catch { return nil }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        child.waitUntilExit()
        return AeroSpaceVersion.parse(versionOutput: String(decoding: data, as: UTF8.self))
    }
}
